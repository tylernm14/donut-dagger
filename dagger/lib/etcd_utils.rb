require 'etcd'
require 'connection_pool'
require 'json'

module EtcdUtils

  class Configuration
    attr_accessor :url, :port, :pool_size, :timeout

    def initialize
      @url = ENV['ETCD_ADDR'] || 'localhost'
      @port = (ENV['ETCD_PORT'] || 4001).to_i
      @pool_size = 5
      @timeout = 10
    end

  end

  class << self
    attr_writer :configuration
  end

  def self.configuration
    @configuration ||=  Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  def self.pool
    @pool ||=  ConnectionPool.new(size: self.configuration.pool_size, timeout: self.configuration.timeout) do
      Etcd.client(host: self.configuration.url, port: self.configuration.port)
    end
  end

end

class EtcdLock
  class LockKeyNotFound < Exception
  end

  def initialize(lock_key, timeout)
    @lock_key = lock_key
    @timeout = timeout
    @locked = false
    @deleted = false
    setup
    setup_thread_index
  end

  def with_lock(timeout=nil)
    raise LockKeyNotFound.new("Lock key '#{@lock_key}' not found in etcd") if !lock_key_exists?
    @timeout = timeout if timeout
    begin
      acquire
      yield
    ensure
      release
    end
  end

  def lock_key_exists?
    EtcdUtils.pool.with do |conn|
      conn.exists?(@lock_key)
    end
  end

  def has_lock?
    @locked
  end

  def delete
    EtcdUtils.pool.with do |conn|
      conn.delete(@lock_key).node.value
    end
    @locked = false
    @deleted = true
  end

  private

  def setup
    EtcdUtils.pool.with do |conn|
      if not conn.exists?(@lock_key)
        # TODO:  Make sure that the lock has a ttl. Can use 'set' with prevExists
        conn.set(@lock_key, value: 0)
      else
        puts "Lock key '#{@lock_key}' already exists."
      end
    end
  end

  def setup_thread_index
    @thread_ttl = 2*60*60 # cleanup key after 2 hours
    @thread_key = "/dagger/thread_id_index/#{SecureRandom.uuid}"
    EtcdUtils.pool.with do |conn|
      @thread_etcd_index = conn.set(@thread_key, value: 0, ttl: @thread_ttl).node.modified_index
    end
  end

  def acquire
    begin
      test_and_set_with_timeout(@timeout, @lock_key, {value: @thread_etcd_index, prevValue: 0})
      @locked = true
      puts "Acquired lock #{@lock_key}"
    rescue Timeout::Error => e
      $stderr.puts "Couldn't acquire lock '#{@lock_key}' in #{@timeout} seconds"
      raise e
    end
  end

  def release
    if @locked
      begin
        test_and_set_with_timeout(@timeout, @lock_key, {value: 0, prevValue: @thread_etcd_index})
        @locked = false
      rescue Timeout::Error => e
        # Lock taken by another client...
        $stderr.puts "Couldn't release lock '#{@lock_key}' in #{@timeout} seconds"
        raise e
      end
      puts "Released lock #{@lock_key}"
      if $!
        $stderr.puts "Error raised in 'with_lock'."
      end
    elsif @deleted
      puts "No need to release lock #{@lock_key}.  Workflow has already been deleted"
    end

  end


  def test_and_set_with_timeout(watch_timeout, key, params)
    raise ValueError('Timeout is nil') if not watch_timeout
    key_set = false
    updated_key = nil
    result = Timeout::timeout(watch_timeout) do
      EtcdUtils.pool.with do |conn|
        while not key_set do
          begin
            updated_key = conn.test_and_set(key, params)
            key_set = true
          rescue Etcd::TestFailed => e
            puts "Failed test and set on '#{key}' to value '#{params[:value]}' with prevValue '#{params[:prevValue]}'.  Watching key..."
            conn.watch(@lock_key)
          end
        end
      end
    end
    updated_key
  end
end

class EtcdWorkflowQueue
  def initialize(timeout=5*60)
    @lock_key = "/dagger/workflows/queue_lock"
    @lock = EtcdLock.new(@lock_key, timeout)
    @queue_dir = "/dagger/workflows/queue"
  end

  def with_lock(timeout=nil)
    @lock.with_lock(timeout) do
      yield self
    end
  end

  def add(workflow_uuid)
    EtcdUtils.pool.with do |conn|
      conn.create_in_order(@queue_dir, value: workflow_uuid).node.key
    end
  end

  def delete(key, opts={})
    EtcdUtils.pool.with do |conn|
      conn.delete("#{@queue_dir}/#{key}", opts).node.value
    end
  end

  def get
    EtcdUtils.pool.with do |conn|
     dir = conn.get("#{@queue_dir}", sorted: true)
     dir.node.children.map {|c| c.value}
    end
  end
end

# Lazy evaluated job fetcher of workflow as represented in etcd
class EtcdWorkflow

  def initialize(workflow_uuid, timeout=5*60)
    @workflow_uuid = workflow_uuid
    @timeout = timeout
    @workflow_base = "/dagger/workflows/#{workflow_uuid}"
    @lock_key = "#{@workflow_base}/lock"
    @lock = EtcdLock.new(@lock_key, timeout)
    #@workflow_queue = "/dagger/workflows/queue"
    #@workflow_queue_key = nil
  end

  def delete
    @lock.delete
    EtcdUtils.pool.with do |conn|
      conn.delete(@workflow_base, { 'recursive' => 'true'}).node.value
    end
  end

  def with_lock(timeout=nil)
    expire_jobs_cache
    @lock.with_lock(timeout) do
      yield self
    end
  end

  #def enqueue
    #EtcdUtils.pool.with do |conn|
      #conn.create_in_order(@workflow_queue, value: @workflow_uuid)
      #@workflow_queue_key = response.node.key
    #end
  #end

  #def dequeue
    #EtcdUtils.pool.with do |conn|
      #if @workflow_queue_key
        #response = conn.delete(@workflow_queue_key)
      #else
        #raise "Workflow #{@workflow_uuid} not enqueued"
      #end
    #end
  #end

  def set_status(status)
    key = "#{@workflow_base}/status"
    EtcdUtils.pool.with do |conn|
      conn.set(key, value: "#{status}").node.value
    end
  end

  def get_status
    key = "#{@workflow_base}/status"
    EtcdUtils.pool.with do |conn|
      conn.get(key).node.value
    end
  end

  def expire_jobs_cache
    @jobs = nil
  end

  def jobs_by_status(status)
    jobs.select { |uuid, job| job['status'] == "#{status}" }
  end

  def jobs
    @jobs ||= EtcdUtils.pool.with do |conn|
      key = "#{@workflow_base}/jobs/"
      res = conn.exists?(key)
      if conn.get(key).inspect
        conn.get(key).node.children.map { |c| [c.key.split('/').last, JSON.parse(c.value)] }.to_h
      else
        {}
      end
    end
  end

  # each job is a key with a json object as value
  def job_exists?(job_uuid)
    res = false
    EtcdUtils.pool.with do |conn|
      key = "#{@workflow_base}/jobs/#{job_uuid}/"
      res = conn.exists?(key)
    end
    res
  end

  def get_job(job_uuid)
    EtcdUtils.pool.with do |conn|
      key = "#{@workflow_base}/jobs/#{job_uuid}/"
      JSON.parse(conn.get(key).node.value)
    end
  end

  def set_job(job)
    norm_job = stringify_all_keys(job)
    EtcdUtils.pool.with do |conn|
      key = "#{@workflow_base}/jobs/#{norm_job['uuid']}"
      resp = conn.set(key, value: JSON.pretty_generate(norm_job))
      jobs[norm_job['uuid']] = JSON.parse(resp.node.value)
    end
  end

  def stringify_all_keys(hash)
    stringified_hash = {}
    hash.each do |k, v|
      stringified_hash[k.to_s] = v.is_a?(Hash) ? stringify_all_keys(v) : v
    end
    stringified_hash
  end

  def update_job_status(job_uuid, status)
    EtcdUtils.pool.with do |conn|
      key = "#{@workflow_base}/jobs/#{job_uuid}"
      job = {}
      if conn.exists?(key)
        resp = conn.get(key)
        job = JSON.parse(resp.value)
      else
        raise "Job with uuid #{job_uuid} doesn't exist."
      end
      job['status'] = status
      updated_job = JSON.pretty_generate(job)
      resp = conn.set(key, value: updated_job)
      jobs[job_uuid]['status'] = JSON.parse(resp.node.value)['status']
    end
  end

  def self.job_repr(job, options=nil)
    repr = {
      'uuid' => job.uuid,
      'name' => job.name,
      'dependencies_count' => job.dependencies_count,
      'dependencies_succeeded_count' => job.dependencies_succeeded_count,
      'dependents_count' => job.dependents_count,
      'status' => job.status
    }
    repr.merge!(options) if options
    repr
  end

end
