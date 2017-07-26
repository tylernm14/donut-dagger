require 'rest-client'
require_relative '../../app/models/workflow'
require_relative '../../app/models/job'
require_relative '../../app/models/root'
require_relative '../../app/workers/start_workflow_worker'

# Litle in memory data stricture for cycle checking before
#    storing data to db
class Dag
  attr_accessor :num_jobs
  attr_accessor :neighbors
  def initialize(job_descriptions, neighbors)
    @num_jobs  = job_descriptions.size
    @jobs      = job_descriptions
    @neighbors = neighbors
  end

  def has_cycle?
    @visited = {}
    @rstack = {} # Recursion stack
    @jobs.each do |j|
      @visited[j['name']] = false
      @rstack[j['name']] = false
    end
    @jobs.each do |j|
      return true if has_cycle_util?(j['name'], @visited, @rstack)
    end
    return false
  end

  private

  def has_cycle_util?(job_name, visited, rstack)
    if !visited[job_name]
      visited[job_name] = true
      rstack[job_name] = true
      @neighbors[job_name].each do |neighbor|
        if(!visited[neighbor] && has_cycle_util?(job_name, visited, rstack))
          return true
        elsif rstack[neighbor] # case where job neighbor exists in the recursion stack
          $stderr.puts "Found cycle. Job \"#{job_name}\" points to \"#{neighbor}\"."
          return true
        end
      end if @neighbors[job_name]
    end
    rstack[job_name] = false
    return false
  end


  def get_roots()
  end
end


class CreateDagJobs

  attr_accessor :num_jobs

  def self.call(workflow)
    # Parse the jobs form the description and create them and their edges
    job_descriptions = workflow.definition.data['jobs']
    neighbors = workflow.definition.data['neighbors']
    job_graph = Dag.new(job_descriptions, neighbors)
    raise 'Job has cycles.' if job_graph.has_cycle?

    # Create job records
    jobs_with_counts = {}
    jobs = {}
    job_descriptions.each do | job_desc |
      job_name = job_desc['name']
      job_dependents_count = neighbors.fetch(job_name, []).size
      jobs[job_name] = Job.new({workflow: workflow, name: job_name, status: :waiting,
                                        description: job_desc})
      jobs_with_counts[job_name] = {}
      jobs_with_counts[job_name]['dependents_count'] = job_dependents_count
      jobs_with_counts[job_name]['dependencies_count'] = 0
    end
    # Calculate the number of dependencies for each job
    # neighbors.each_pair do |_, dependents|
    #   dependents.each { |d| puts "Adding dependency for #{jobs[d].id}"; Job.increment_counter(:dependencies_count, jobs[d].id)}
    # end
    # Calculate the number of dependencies for each job
    neighbors.each_pair do |job_name, dependents|
      dependents.each { |d| jobs_with_counts[d]['dependencies_count'] = jobs_with_counts[d]['dependencies_count'] + 1 }
    end

    tentative_roots = []
    jobs_with_counts.each_pair { |name, counts| tentative_roots << name if counts['dependencies_count'] == 0 }
    raise 'Could not find any roots' unless tentative_roots.size > 0
    # persist the jobs
    jobs.each_pair do |_, record|
      record.save!
      record.reload  # get the database generated uuid
    end

    jobs.each_pair do | name, record |
      if neighbors[name]
        neighbors[name].each do |dependent|
          #puts "Dependency: #{name} Dependent: #{dependent}"
          JobEdge.create!(workflow: workflow, dependency: record, dependent: jobs[dependent])
        end
      end
    end

    # TODO: maybe find root node using algorithm instead of convention
    # Calcuate number of dependencies for each job
    # root_job = jobs[workflow.definition.data['root']] # TODO: Need some error handling in case there is no root job
    root_jobs = find_root_jobs(jobs.values)
    # puts "Root jobs found #{root_jobs.inspect}"
    root_jobs.each { |root| Root.create(workflow: workflow, job: root) }
    # workflow.root_job_uuid = root_job.uuid
    workflow.save!
  end

  def self.find_root_jobs(jobs)
    root_jobs = []
    jobs.each do |job|
      if job.dependencies_count == 0
        root_jobs.push(job)
        # puts "Found root '#{job.name}'"
      end
    end
    root_jobs
  end

end
