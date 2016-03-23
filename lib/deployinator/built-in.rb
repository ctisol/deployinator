set :webserver_socket_path,       -> { shared_path.join('run') }
set :deploy_templates_path,       "templates/deploy"
set :jobs_app_name,               "jobs"
set :deploy_custom_container_options, -> {} # Set customer Docker options w/o overriding methods below

# Default deploy_to directory is /var/www/my_app
# set :deploy_to, '/var/www/my_app'

# Default value for :log_level is :debug
set :log_level, :info

# Default value for :linked_files is []
# set :linked_files, %w{config/database.yml}

# Default value for linked_dirs is []
# set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

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
set :migration_role,                :db                   # Defaults to 'db'
#set :conditionally_migrate,         true                  # Defaults to false. If true, it's skip migration if files in db/migrate not modified
set :assets_roles,                  [:app]                # Defaults to [:web]
#set :assets_prefix,                'prepackaged-assets'  # Defaults to 'assets' this should match config.assets.prefix in your rails config/application.rb

# # TODO: fix from_local, right now you have to copy-paste the set_scm method to your deploy.rb
# # Use `cap <stage> deploy from_local=true` to deploy your locally changed code
# #   instead of the code in the git repo. You can also add --trace.
# # You can set include_dir and exclude_dir settings (from capistrano-scm-copy gem).
# #   These will only apply when using the from_local=true option
# # set :include_dir, '../.*'
# # set :exclude_dir, ["../.$", "../..", '.././infrastructure']
# def set_scm
#   if ENV['from_local']
#     if "#{fetch(:stage)}" == "production"
#       run_locally do
#         fatal("You are trying to deploy to production using from_local, " +
#           "this should pretty much never be done.")
#       end
#       ask :yes_no, "Are you positive you want to continue?"
#       case fetch(:yes_no).chomp.downcase
#       when "yes"
#       when "no"
#         exit
#       else
#         warn "Please enter 'yes' or 'no'"
#         set_scm
#       end
#     end
#     set :scm, :copy
#   else
#     set :scm, :git
#   end
# end
# set_scm

def deploy_run_bluepill(host)
  warn "Starting a new container named #{fetch(:ruby_container_name)} on #{host}"
  execute(
    "docker", "run", "--tty", "--detach",
    "--name", fetch(:ruby_container_name),
    "-e", "APP_STAGE=#{fetch(:stage)}",
    "-e", "RAILS_ROOT=#{current_path}",
    "-e", "GEM_HOME=#{shared_path.join('bundle')}",
    "-e", "GEM_PATH=#{shared_path.join('bundle')}",
    "-e", "BUNDLE_GEMFILE=#{current_path.join('Gemfile')}",
    "-e", "PATH=#{shared_path.join('bundle', 'bin')}:$PATH",
    fetch(:deploy_custom_container_options),
    "--restart", "always", "--memory", "#{fetch(:ruby_container_max_mem_mb)}m",
    "--volume", "#{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
    "--entrypoint", shared_path.join('bundle', 'bin', 'bluepill'),
    fetch(:ruby_image_name), "load",
    current_path.join('config', 'bluepill.rb')
  )
end
def deploy_bluepill_restart(host)
  execute(
    "docker", "exec", "--tty",
    fetch(:ruby_container_name),
    shared_path.join('bundle', 'bin', 'bluepill'),
    fetch(:application), "restart"
  )
end
def deploy_bluepill_stop(host)
  execute(
    "docker", "exec", "--tty",
    fetch(:ruby_container_name),
    shared_path.join('bundle', 'bin', 'bluepill'),
    fetch(:application), "stop"
  )
end
def deploy_run_bluepill_jobs(host)
  execute(
    "docker", "run", "--tty", "--detach",
    "-w", current_path,
    "--user", fetch(:webserver_username),
    "--name", fetch(:ruby_jobs_container_name),
    "-e", "APP_STAGE=#{fetch(:stage)}",
    "-e", "RAILS_ROOT=#{current_path}",
    "-e", "GEM_HOME=#{shared_path.join('bundle')}",
    "-e", "GEM_PATH=#{shared_path.join('bundle')}",
    "-e", "BUNDLE_GEMFILE=#{current_path.join('Gemfile')}",
    "-e", "PATH=#{shared_path.join('bundle', 'bin')}:$PATH",
    fetch(:deploy_custom_container_options),
    "--restart", "always", "--memory", "#{fetch(:ruby_jobs_container_max_mem_mb)}m",
    "--volume", "#{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
    "--entrypoint", shared_path.join('bundle', 'bin', 'rabid_jobs_tasker'),
    fetch(:ruby_image_name), "--rails_root", current_path,
    "--environment", fetch(:rails_env), "--pid", "#{fetch(:webserver_socket_path)}/jobs.pid", "--maxworkers", "3"
  )
end
def deploy_run_cadvisor(host)
  execute(
    "docker", "run", "--detach",
    "--name", "cadvisor",
    "--volume", "/:/rootfs:ro",
    "--volume", "/var/run:/var/run:rw",
    "--volume", "/sys:/sys:ro",
    "--volume", "/var/lib/docker/:/var/lib/docker:ro",
    "--publish", "127.0.0.1:8080:8080",
    "--restart", "always",
    "google/cadvisor:latest"
  )
end
def deploy_rails_console(host)
  [
    "ssh", "-t", "#{host}", "\"docker", "exec", "--interactive", "--tty",
    fetch(:ruby_container_name),
    # "sudo", "-u", fetch(:webserver_username), TODO, make sure it works to add this line
    "bash", "-c", "'cd", current_path, "&&",
    shared_path.join('bundle', 'bin', 'rails'),
    "console", "#{fetch(:rails_env)}'\""
  ].join(' ')
end
def deploy_rails_console_print(host)
  [
    "docker", "exec", "--interactive", "--tty",
    fetch(:ruby_container_name),
    "bash", "-c", "\"cd", current_path, "&&",
    shared_path.join('bundle', 'bin', 'rails'),
    "console", "#{fetch(:rails_env)}\""
  ].join(' ')
end
def sshkit_bundle_command_map
  [
    "/usr/bin/env docker run --rm --tty",
    "--user", fetch(:deployment_username),
    "-e", "GEM_HOME=#{shared_path.join('bundle')}",
    "-e", "GEM_PATH=#{shared_path.join('bundle')}",
    "-e", "PATH=#{shared_path.join('bundle', 'bin')}:$PATH",
    "--volume", "#{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
    "--volume", "$SSH_AUTH_SOCK:/ssh-agent:rw", "--env SSH_AUTH_SOCK=/ssh-agent",
    "--volume", "/home:/home:rw",
    "--volume", "/etc/passwd:/etc/passwd:ro",
    "--volume", "/etc/group:/etc/group:ro",
    "--entrypoint", "#{shared_path.join('bundle', 'bin', 'bundle')}",
    fetch(:ruby_image_name)
  ].join(' ')
end
def deploy_assets_precompile(host)
  execute(
    "docker", "run", "--rm", "--tty", "--user", fetch(:webserver_username),
    "-e", "APP_STAGE=#{fetch(:stage)}",
    "-e", "RAILS_ROOT=#{current_path}",
    "-w", release_path,
    "--volume", "/home:/home:rw",
    "--volume", "/etc/passwd:/etc/passwd:ro",
    "--volume", "/etc/group:/etc/group:ro",
    "--volume", "#{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
    fetch(:deploy_custom_container_options),
    "--entrypoint", "/bin/bash",
    fetch(:ruby_image_name), "-c",
    "\"umask", "0007", "&&", "#{shared_path.join('bundle', 'bin', 'rake')}",
    "assets:precompile\""
  )
end
def deploy_assets_cleanup(host)
  execute(
    "docker", "run", "--rm", "--tty",
    "-e", "RAILS_ENV=#{fetch(:rails_env)}",
    "-w", release_path,
    fetch(:deploy_custom_container_options),
    "--volume", "#{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
    "--entrypoint", shared_path.join('bundle', 'bin', 'bundle'),
    fetch(:ruby_image_name), "exec", "rake", "assets:clean"
  )
end
def deploy_rake_db_migrate(host)
  execute(
    "docker", "run", "--rm", "--tty",
    "-w", release_path,
    "-e", "APP_STAGE=#{fetch(:stage)}",
    "-e", "RAILS_ROOT=#{current_path}",
    "-e", "RAILS_ENV=#{fetch(:rails_env)}",
    fetch(:deploy_custom_container_options),
    "--volume", "#{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
    "--entrypoint", shared_path.join('bundle', 'bin', 'rake'),
    fetch(:ruby_image_name), "db:migrate"
  )
end
def deploy_install_bundler(host)
  execute(
    "docker", "run", "--rm", "--tty", "--user", fetch(:deployment_username),
    "-e", "GEM_HOME=#{shared_path.join('bundle')}",
    "-e", "GEM_PATH=#{shared_path.join('bundle')}",
    "-e", "PATH=#{shared_path.join('bundle', 'bin')}:$PATH",
    "--volume", "#{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
    "--volume", "/home:/home:rw",
    "--volume", "/etc/passwd:/etc/passwd:ro",
    "--volume", "/etc/group:/etc/group:ro",
    "--entrypoint", "/bin/bash",
    fetch(:ruby_image_name), "-c",
    "\"umask", "0007", "&&" "/usr/local/bin/gem", "install",
    "--install-dir", "#{shared_path.join('bundle')}",
    "--bindir", shared_path.join('bundle', 'bin'),
    "--no-ri", "--no-rdoc", "--quiet", "bundler", "-v'#{fetch(:bundler_version)}'\""
  )
end
