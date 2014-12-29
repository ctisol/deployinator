# config valid only for Capistrano 3.1
lock '3.2.1'

set :application,                 'my_app_name'
set :repo_url,                    'git@example.com:me/my_repo.git'
set :preexisting_ssh_user,        ENV['USER']
set :deployment_username,         "deployer" # user with SSH access and passwordless sudo rights
set :webserver_username,          "www-data" # less trusted web server user with limited write permissions

set :webserver_writeable_dirs,    [shared_path.join('run'), shared_path.join("tmp"), shared_path.join("log")]
set :webserver_executable_dirs,   [shared_path.join("bundle", "bin")]
set :ignore_permissions_dirs,     [shared_path.join("postgres")]
set :webserver_socket_path,       shared_path.join('run')

# Default branch is :master
# Always use the master branch in production:
set :current_stage, -> { fetch(:stage).to_s.strip }
unless fetch(:current_stage) == "production"
  ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call
end

# Default deploy_to directory is /var/www/my_app
# set :deploy_to, '/var/www/my_app'

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :linked_files is []
# set :linked_files, %w{config/database.yml}

# Default value for linked_dirs is []
# set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5


#----------------------------------------------------
## The values below shouldn't need changed under the majority of circumstances.

# Use `cap <stage> deploy from_local=true` to deploy your
#   locally changed code instead of the code in the git repo. You can also add --trace.
if ENV['from_local']
  if fetch(:current_stage) == "production"
    run_locally do
      fatal "You are trying to deploy to production using from_local, this should pretty much never be done."
    end
    ask :yes_no, "Are you positive you want to continue?"
    if fetch(:yes_no).chomp.downcase == "yes"
      set :scm, :copy
    else
      exit
    end
  end
else
  set :scm, :git
end

#set :bundle_roles, :all                                         # this is default
#set :bundle_servers, -> { release_roles(fetch(:bundle_roles)) } # this is default
#set :bundle_binstubs, -> { shared_path.join('bin') }            # this is default
#set :bundle_binstubs, -> { shared_path.join('bundle', 'bin') }  # this will be overwritten by deployinator
#set :bundle_gemfile, -> { release_path.join('Gemfile') }        # this will be overwritten by deployinator
#set :bundle_path, -> { shared_path.join('bundle') }             # this is default
#set :bundle_without, %w{development test}.join(' ')             # this is default
#set :bundle_flags, '--deployment --quiet'                       # this is default
#set :bundle_flags, '--deployment'
#set :bundle_env_variables, {}                                   # this is default

set :docker_run_bluepill_command, -> { [
  "--tty", "--detach",
  "--name", fetch(:ruby_container_name),
  "-e", "GEM_HOME=#{shared_path.join('bundle')}",
  "-e", "GEM_PATH=#{shared_path.join('bundle')}",
  "-e", "BUNDLE_GEMFILE=#{current_path.join('Gemfile')}",
  "-e", "PATH=#{shared_path.join('bundle', 'bin')}:$PATH",
  "--link", "#{fetch(:postgres_container_name)}:postgres",
  "--volume", "#{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
  "--entrypoint", shared_path.join('bundle', 'bin', 'bluepill'),
  "--restart", "always", "--memory", "#{fetch(:ruby_container_max_mem_mb)}m",
  fetch(:ruby_image_name), "load",
  current_path.join('config', 'bluepill.rb')
] }

set :docker_run_cadvisor_command, -> { [
  "--detach",
  "--name", "cadvisor",
  "--volume", "/:/rootfs:ro",
  "--volume", "/var/run:/var/run:rw",
  "--volume", "/sys:/sys:ro",
  "--volume", "/var/lib/docker/:/var/lib/docker:ro",
  "--publish", "127.0.0.1:8080:8080",
  "--restart", "always",
  "google/cadvisor:latest"
] }
