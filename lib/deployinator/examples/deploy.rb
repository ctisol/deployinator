# config valid only for Capistrano 3.1
lock '3.2.1'

set :application, 'my_app_name'
set :repo_url, 'git@example.com:me/my_repo.git'

## Don't ask this here, only in staging or other non-production <stage>.rb files.
# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call

# Default deploy_to directory is /var/www/my_app
# set :deploy_to, '/var/www/my_app'

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# set :linked_files, %w{config/database.yml}

# Default value for linked_dirs is []
# set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}
set :linked_dirs, %w{log tmp}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

namespace :deploy do

  ### No need to do anything here, deployinator defines this task.
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      # execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

end

# Use `cap <stage> deploy from_local=true` to deploy your
#   locally changed code instead of the code in the git repo. You can also add --trace.
if ENV['from_local']
  set :scm, :copy
else
  set :scm, :git
end

  ## For a standard Ubuntu 12.04 Nginx Docker image you should only
  ##  need to change the following values to get started:

  ## The values below may be commonly changed to match specifics
  ##  relating to a particular Docker image or setup:

set :internal_sock_path, "/var/run/unicorn"

  ## The values below are not meant to be changed and shouldn't
  ##  need to be under the majority of circumstances:


#set :bundle_roles, :all                                         # this is default
#set :bundle_servers, -> { release_roles(fetch(:bundle_roles)) } # this is default
#set :bundle_binstubs, -> { shared_path.join('bin') }            # this is default
set :bundle_binstubs, -> { shared_path.join('bundle', 'bin') }  # this is required for deployinator
set :bundle_gemfile, -> { release_path.join('Gemfile') }        # this is required for deployinator
#set :bundle_path, -> { shared_path.join('bundle') }             # this is default
#set :bundle_without, %w{development test}.join(' ')             # this is default
set :bundle_without, %w{development test deployment}.join(' ')
set :bundle_flags, '--deployment --quiet'                       # this is default
#set :bundle_flags, '--deployment'
#set :bundle_env_variables, {}                                   # this is default
