# config valid only for Capistrano 3.2.1
lock '3.2.1'

##### deployinator
### ------------------------------------------------------------------
set :repo_url,                      'git@example.com:me/my_repo.git'
set :application,                   'my_app_name'
set :preexisting_ssh_user,          ENV['USER']
set :deployment_username,           "deployer" # user with SSH access and passwordless sudo rights
set :webserver_username,            "www-data" # less trusted web server user with limited write permissions
set :database_name,                 "db_name"
set :database_username,             "db_username"
set :database_password,             "db_password"
# All permissions changes are recursive, and unless overridden below,
#   all folders will be "deployer www-data drwxr-s---",
#   all files will be   "deployer www-data -rw-r-----"
set :webserver_owned_dirs,          [shared_path.join('tmp', 'cache'), shared_path.join('public', 'assets')]
set :webserver_writeable_dirs,      [shared_path.join('run'), shared_path.join("tmp"), shared_path.join("log")]
set :webserver_executable_dirs,     [shared_path.join("bundle", "bin")]
set :ignore_permissions_dirs,       [shared_path.join("postgres"), shared_path.join("nginx"), "#{fetch(:deploy_to)}/releases"]

# Default value for linked_dirs is []
# set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

set :bundler_version,               "1.7.4"
set :use_cadvisor,                  true
### ------------------------------------------------------------------
