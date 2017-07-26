ENV['APP_NAME'] = 'cellar' # MUST BE AT TOP
require 'carrierwave'
require 'carrierwave/storage/abstract'
require 'carrierwave/storage/file'
require 'carrierwave/storage/fog'

CarrierWave.configure do |config|
  puts "Configuring carrierwave with ENV['APP_NAME']: #{ENV['APP_NAME']}"
  if ENV['RACK_ENV'] == 'test'
    config.root = 'tmp'
    config.storage = :file
    config.enable_processing = false
  elsif ENV['RACK_ENV'] != 'production' &&
      ENV['RACK_ENV'] != 'staging' &&
      ENV['USE_S3_ASSET'].nil?
    if ENV['SHARED_FS_MOUNT_PATH'] && ENV['RACK_ENV'] == 'local'
      config.root = File.join(ENV['SHARED_FS_MOUNT_PATH'],'donut-dagger', ENV['APP_NAME'], 'cw')
    else
      config.root = "/tmp/donut-dagger/#{ENV['APP_NAME']}/cw"
    end
    config.storage = :file
  else
    config.storage = :fog
    config.fog_provider = "fog/aws"
    config.fog_credentials = {
        provider: 'AWS',
        region: ENV['AWS_REGION'],
        aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    }
    config.fog_directory = "#{ENV['APP_NAME']}-#{ENV['RACK_ENV'] == 'toolbox' ? 'development' : ENV['RACK_ENV']}"
    config.fog_public = false
    config.fog_authenticated_url_expiration = 60
  end
  puts "Carrierwave root at '#{config.root}'"
end