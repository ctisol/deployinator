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
