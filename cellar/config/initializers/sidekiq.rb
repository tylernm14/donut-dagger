require 'sidekiq'

# :nocov:
class WithHostnameFormatter < Sidekiq::Logging::Pretty
  def call(severity, time, program_name, message)
    "#{ENV['HOSTNAME'] || 'localhost'} - - [#{time.strftime('%d/%b/%Y:%H:%M:%S %z')}] #{::Process.pid} TID-#{Thread.current.object_id.to_s(36)}#{context} #{severity}: #{message}\n"
  end
end
# :nocov:

Sidekiq.logger.formatter = WithHostnameFormatter.new