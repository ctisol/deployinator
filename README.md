deployinator
============

Opinionatedly Deploy Applications

This gem is a work in progress, more explanation will be added later.

TODO
* Fill out this readme
* Fix bug with deployment_authorized_keys first time setup, passed wrong templates path ('postgres/deployment..' instead of 'deploy/deployment...')
* Fix deploy from_local=true to work without copying it to `config/deploy.rb`
* Create task to create the shared_path.join("run") directory
* Add a methodology to set environment variables for the containers (without overridding all the built-ins)
* Change deployinator to use `host.postgres_port` (like postgresinator) in place of `set :postgres_port`
* Create task that writes `database.yml` dynamically?
* Skip db:migrate if the database is not running instead of failing the deploy
* Remove brakeman reminder from deployinator
* Create ability to set UNIX environment variables in the containers without overridding default task definitions
* Create ability to set volume mounts setting for all containers like "set :docker_volumes, [fetch(:deploy_to, fetch(:api_deploy_to)]"
* Make chmod/chown faster
* Remove ruby from ruby_container_name ruby_image_name, etc
* Remove bluepill names, ditto
* Setup mechanism to run other "setup" tasks before deploy if they've not been run before (locking mechanism?)
* Move unicorn.rb.erb functionality to more abstract config file uploads, - maybe scripts.d/ style
* Add a 'non-interactive=true' switch to all interactive questions
* Add a task to check for a full disk before continuing a deploy (a full disk causes agent forwarding to fail with "Permission denied (publickey)" error since /tmp cannot be written to).
* Remove brakeman warning
* Add a hook to run all `<inator gem>:check:settings` tasks before everything else
