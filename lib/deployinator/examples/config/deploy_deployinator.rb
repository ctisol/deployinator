# Use `cap <stage> deploy from_local=true` to deploy your
#   locally changed code instead of the code in the git repo. You can also add --trace.
if ENV['from_local']
  set :scm, :copy
else
  set :scm, :git
end

# Always use the master branch in production:
set :current_stage, -> { fetch(:stage).to_s.strip }
unless fetch(:current_stage) == "production"
  ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call
end

## The values in this file are not meant to be changed and shouldn't
##  need to be under the majority of circumstances:

#set :bundle_roles, :all                                         # this is default
#set :bundle_servers, -> { release_roles(fetch(:bundle_roles)) } # this is default
#set :bundle_binstubs, -> { shared_path.join('bin') }            # this is default
set :bundle_binstubs, -> { shared_path.join('bundle', 'bin') }  # this is required for deployinator
set :bundle_gemfile, -> { release_path.join('Gemfile') }        # this is required for deployinator
#set :bundle_path, -> { shared_path.join('bundle') }             # this is default
#set :bundle_without, %w{development test}.join(' ')             # this is default
set :bundle_without, %w{development test deployment}.join(' ')
#set :bundle_flags, '--deployment --quiet'                       # this is default
#set :bundle_flags, '--deployment'
#set :bundle_env_variables, {}                                   # this is default

set :docker_run_bluepill_command, -> { [
  "--tty", "--detach",
  "--name", fetch(:ruby_container_name),
  "-e", "GEM_HOME=#{fetch(:deploy_to)}/shared/bundle",
  "-e", "GEM_PATH=#{fetch(:deploy_to)}/shared/bundle",
  "-e", "BUNDLE_GEMFILE=#{fetch(:deploy_to)}/current/Gemfile",
  "-e", "PATH=#{fetch(:deploy_to)}/shared/bundle/bin:$PATH",
  "--link", "#{fetch(:postgres_container_name)}:postgres",
  "--volume", "#{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
  "--volume", "#{fetch(:external_socket_path)}:#{fetch(:internal_socket_path)}:rw",
  "--entrypoint", "#{fetch(:deploy_to)}/shared/bundle/bin/bluepill",
  "--restart", "always", "--memory", "#{fetch(:ruby_container_max_mem_mb)}m",
  fetch(:ruby_image_name), "load",
  "#{fetch(:deploy_to)}/current/config/#{fetch(:application)}_bluepill.rb"
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
