deployinator
============

Opinionatedly Deploy Applications

TODO
* Fill out this readme
* Fix bug with deployment_authorized_keys first time setup, passed wrong templates path ('postgres/deployment..' instead of 'deploy/deployment...')
* Fix deploy from_local=true to work without copying it to `config/deploy.rb` - then setup capistrano-notify-hubot to report "from_local" for the branch
* Create task to create the shared_path.join("run") directory
* Add a methodology to set environment variables for the containers (without overridding all the built-ins)
* Change deployinator to use `host.postgres_port` (like postgresinator) in place of `set :postgres_port`
* Create task that writes `database.yml` dynamically?
* Skip db:migrate if the database is not running instead of failing the deploy
* Remove brakeman reminder from deployinator
* Create ability to set custom additions to the ruby containers without overridding default task definitions (e.g. volume mounts and environment variables)
* Make chmod/chown faster
* Remove ruby from ruby_container_name ruby_image_name, etc
* Remove bluepill names, ditto
* Setup mechanism to run other (inator) gem's "setup" tasks before deploy if they've not been run before (locking mechanism?)
* Move unicorn.rb.erb functionality to more abstract config file uploads, - maybe scripts.d/ style
* Add a 'non-interactive=true' switch to all interactive questions
* Add a task to check for a full disk before continuing a deploy (a full disk causes agent forwarding to fail with "Permission denied (publickey)" error since /tmp cannot be written to).
* Remove brakeman warning
* Add a hook to run all `<inator gem>:check:settings` tasks before everything else
* Use a lock file to auto-detect when docker run commands have changed, - and recreate containers instead of restarting them.
* Run permissions task durring a deploy:restart:force
* Don't chmod `releases` dir
* Maybe don't run `file_permission` task during restart?
* Make `force:restart` also run `jobs:force:restart` if jobs are enabled.
