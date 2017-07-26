class AddKubeJobNameToJobs < ActiveRecord::Migration
  def change
    add_column :jobs, :kube_job_name, :string
  end
end
