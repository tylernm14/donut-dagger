require_relative '../app/models/result'
require_relative '../app/models/workflow_env'
require_relative '../app/models/local_input'

# Matching id and uuids from dagger/db/seeds.rb
Result.create!(workflow_id: 1, job_id: 1, job_name: 'apple', name: 'file.zip', file: File.open(File.expand_path('../../file.zip', __FILE__)))
Result.create!(workflow_id: 1, job_id: 1, job_name: 'apple', name: 'chicken_cat.jpeg', file: File.open(File.expand_path('../../chicken_cat.jpeg', __FILE__)))
WorkflowEnv.create!(workflow_uuid: '97471d6d-ccc7-44a8-a1d6-a581f9684312', status: :saved, zip_file: File.open(File.expand_path('../../file.zip', __FILE__)))
LocalInput.create!(workflow_uuid: '97471d6d-ccc7-44a8-a1d6-a581f9684312', name: 'cat.png', file: File.open(File.expand_path('../../cat.png', __FILE__)))
