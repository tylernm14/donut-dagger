# require_relative '../app/models/definition'
# require_relative '../app/models/workflow'
# require_relative '../app/models/job'
Dir.glob('./app/{uploaders,services,models,helpers,controllers,workers}/*.rb').each { |file| require file }

definition_hash = {
  name: "yada2",
  description: "tyler seed",
  data: {
    "jobs"=>
    [
      {"cmd"=>"/timer.py", "args"=>["30s"], "name"=>"apple", "image"=>"timer:mine"},
      {"cmd"=>"/timer.py", "args"=>["2m"], "name"=>"banana", "image"=>"timer:mine"},
      {"cmd"=>"/timer.py", "args"=>["20s"], "name"=>"cantaloupe", "image"=>"timer:mine"},
      {"cmd"=>"/timer.py", "args"=>["10s"], "name"=>"dragonfruit", "image"=>"timer:mine"}
    ],
    "root"=>"apple",
    "neighbors"=>{
      "apple"=>["banana", "cantaloupe"],
      "banana"=>["dragonfruit"],
      "cantaloupe"=>["dragonfruit"]},
    "parallelism"=>4
  }
}

id = Definition.create!(definition_hash).id
workflow_hash = {
  uuid: "97471d6d-ccc7-44a8-a1d6-a581f9684312",
  status: 0,
  priority: 0,
  user_oauth_id: 6559182,
  parallelism: 4,
  definition_id: id
}
w = Workflow.create!(workflow_hash)
w.jobs.each do |j|
  j.succeeded!
end

w.done!
