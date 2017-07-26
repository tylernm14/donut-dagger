# donut-dagger

Simple DAG processing built on Kubernetes jobs.

### Overview
Donut-dagger is a full-stack personal project more than a production-level system.  Concepts in donut-dagger are similar to those in projects like Apache Airflow but simplified.  Essentially there is a directed acyclic graph represented by a "Workflow" abstraction, and the nodes of the DAG are reprsented as "Jobs", parameterized batch jobs that map to execution of a Kuberentes job.  Workflow state is stored in etcd and a horizonatally scalable scheduler is reponsible for scheduling jobs and handling messaging from finished jobs. Currently jobs can only be executed as Kubernetes jobs.  Pre and post-processing directives exist to grab inputs and save outputs.  To reduce data replication all jobs share a common data volume directly (ie. NFS); however, jobs can create their own directory within the data volume directory for organization.

## Deployment
This project currently runs on minikube using the files in `kube-files/local`.  These files are meant as examples and should be tweaked depending on the deployment situation.  Three services make up donut-dagger: `dagger` is the main service that handles workflows, jobs, and views; `cellar` is a file storage service for hosting workflow results; and `users` manages user api tokens across services.  Donut-dagger relies on GitHub Oauth for account authorization, so a client id and a secret key will need to be generated from a [GitHub application](https://developer.github.com/apps/building-integrations/setting-up-and-registering-oauth-apps/)

## Usage

Goto: [https://where-im-hosted.com/workflows/admin/new]() and create a workflow definition.  Fields exist for a friendly name, level of parallelism, or how many jobs can run simulataneously if dependencies are met, and the definition.  Additionally files can be uploaded and referenced in the definition if they are not externally hosted.

![New Screensshot](https://raw.github.com/tylernm14/donut-dagger/master/readme-media/new_workflow.png)

### Example Workflow Definition
Below is a description of a sample workflow definition, which can be either YAML or JSON.  More samples are at [examples](dagger/public/examples)

#### Jobs
  Below is a basic job with all fields being required.

```yaml
jobs:
- cmd: "/timer.py"
  args:
  - 30s
  name: apple
  image: timer:mine
```

The "jobs" array is an array of hashes where each hash has the following keys:
- `cmd` = command to run in the kubernetes job
- `args` = array of parameteres to the above command
- `name` = friendly name of job
- `image` = docker image to run.  Note: At this time, private image are not supported

TODO: Launch kube job from editable template file so cluster-specify options can be tweaked like 'imagePullSecrets' and 'lablels'.
Job commands are executed by a python wrapper that streams stdout and stderr back to the workflow server for viewing within the donut-dagger GUI. This wrapper also notifies the server of the job's status. To add this wrapper to a docker image simple install the 'streamed-job' package with pip
Or if you'd rather base a new docker image off of your original follow this sample pattern:

```Dockerfile
FROM my_original_image

COPY streamed_job-0.1.0.tar.gz /streamed_job-0.1.0.tar.gz
RUN pip uninstall -y streamed-job; exit 0
RUN pip install /streamed_job-0.1.0.tar.gz
```

Each job can have some optional keys to save input and outputs

```yaml
jobs:
- cmd: "/timer.py"
  args:
  - 30s
  name: apple
  image: timer:mine
  workdir_prefix: apple
  inputs:
  - origin: http://example.com/myfile.zip
    local: myfile.zip
  outputs:
  - save: true
    local: output.txt
```

`workdir_prefix` is an optional path that specifies the working directory for the executed command relative to the mounted workflow directory.  Each kubernetes job mounts a shared volume that stores the workflow data.  For instance a job may have the data volume mounted at `/srv/workflows`.  The executing process within the kubernetes job runs in a workflow directory such as `/srv/workflows/<workflow_uuid>` unless a `workflow_prefix` is defined for a job, which makes the working directory then `/srv/workflows/<workflow_uuid>/<workflow_prefix>`.

Inputs is an optional array of hashes, which correspond to a remote source and local workflow directory destination.
- `origin` = source of input. Requires a matching `local` key
- `cache` = source of input from the 'New Workflow' GUI dropzone.  Requires a matching `local` key
- `local` = Required destination path relative to the working directory.  Specificing `local` without an `origin` or `cache` path simply verifies that the local path does indeed exist relative to the working directory

Outputs is an optional array of hashes. Each entry has the following keys:
- `local` = Required filepath specifiy a file relative to the working directory
- `save` = Optional boolean indicating whether the outputs should be saved a workflow result for viewing within the donut-dagger GUI

### Example Gather Job

```yaml
jobs:
- cmd: "/timer.py"
  args:
  - 30s
  name: apple
  image: timer:mine
  outputs:
  - save: true
    local: output.txt
  workdir_prefix: apple
- cmd: "/timer.py"
  args:
  - 20s
  name: banana
  image: timer:mine
  outputs:
  - save: true
    local: output.txt
  workdir_prefix: banana
- cmd: "/timer.py"
  args:
  - 30s
  name: cantaloupe
  image: timer:mine
  outputs:
  - save: true
    local: output.txt
  workdir_prefix: cantaloupe
- cmd: "/gather_cpu_time.py"
  args:
  - apple
  - banana
  - cantaloupe
  name: dragonfruit
  image: timer:mine
  inputs:
  - local: apple/output.txt
  - local: banana/output.txt
  - local: cantaloupe/output.txt
  outputs:
  - save: true
    local: total_cpu_time.txt
neighbors:
  apple:
  - banana
  - cantaloupe
  banana:
  - dragonfruit
  cantaloupe:
  - dragonfruit
```
