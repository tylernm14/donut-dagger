module Rails
  puts "Loading fake Rails module for warden"
  class MyEnvironment
    def to_sym
      ENV['RACK_ENV'].to_sym
    end
    def test?
      ENV['RACK_ENV'] == 'test'
    end
  end
  def self.env
    @env ||= MyEnvironment.new
  end
end
