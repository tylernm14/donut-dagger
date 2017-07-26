require 'carrierwave'
require 'carrierwave/orm/activerecord'

class AttachmentUploader < CarrierWave::Uploader::Base

  # Include RMagick or MiniMagick support:
  # include CarrierWave::RMagick
  include CarrierWave::MiniMagick

  # process :set_content_type
  process :save_content_type_and_size_in_model

  # Override the directory where uploaded files will be stored.
  # This is a sensible default for uploaders that are meant to be mounted:
  # def store_dir
  #   "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  # end

  # Provide a default URL as a default if there hasn't been a file uploaded:
  # def default_url
  #   # For Rails 3.1+ asset pipeline compatibility:
  #   # ActionController::Base.helpers.asset_path("fallback/" + [version_name, "default.png"].compact.join('_'))
  #   [version_name, 'image.png'].compact.join('_')
  # end

  # Process files as they are uploaded:
  # process :scale => [540, 540]
  #
  # def scale(width, height)
  #   manipulate! do |img|
  #      img = img.scale(540,540)
  #   end
  # end

  def default_url
     # For Rails 3.1+ asset pipeline compatibility:
     # ActionController::Base.helpers.asset_path("fallback/" + [version_name, "default.png"].compact.join('_'))
    "/images/#{version_name}_non_image.png"
  end
  # Create different versions of your uploaded files:
  version :large, if: :image? do
    process :resize_to_fit => [540, 540]
  end

  version :thumb, from_version: :large, if: :image? do
    process :resize_to_fit => [162, 162]
  end

  def filename
    "#{secure_token}.#{file.extension}" if original_filename.present?
  end

  protected
  def secure_token
    var = :"@#{mounted_as}_secure_token"
    model.instance_variable_get(var) or model.instance_variable_set(var, SecureRandom.uuid)
  end

  def image?(new_file)
    file.content_type.start_with? 'image'
  end

  def save_content_type_and_size_in_model
    # replace `file_content_type` with your field name
    model.file_content_type = file.content_type if file.content_type
    model.file_size = file.size if file.size
    model.name = file.original_filename if file.original_filename
  end
end