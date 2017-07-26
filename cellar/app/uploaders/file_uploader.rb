require 'carrierwave'
require 'carrierwave/orm/activerecord'

class FileUploader < CarrierWave::Uploader::Base

  process :save_size_in_model

  def filename
    "#{secure_token}.#{file.extension}" if original_filename.present?
  end

  protected
  def secure_token
    var = :"@#{mounted_as}_secure_token"
    model.instance_variable_get(var) or model.instance_variable_set(var, SecureRandom.uuid)
  end

  def save_size_in_model
    model.zip_file_size = file.size if file.size
  end
end