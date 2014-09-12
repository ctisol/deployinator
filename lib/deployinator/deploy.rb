# config valid only for Capistrano 3.1
lock '3.2.1'

# Use `from_local=true bundle exec cap <stage> deploy` to deploy your
#   locally changed code instead of the code in the git repo.
#   TODO this is not working yet
if ENV['from_local']
  set :repo_url, 'file://.'
  set :scm, :none
else
  set :repo_url, 'git@github.com:snarlysodboxer/example.git'
  set :scm, :git
end

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call

# Default deploy_to directory is /var/www/my_app
# set :deploy_to, '/var/www/my_app'

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
#set :log_level, :debug
set :log_level, :info

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# set :linked_files, %w{config/nginx.conf}

# Default value for linked_dirs is []
# set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

namespace :deploy do

  # :started is the hook before which to set/check your needed environment/settings
  before :started, :ensure_setup

  task :ensure_setup do
    on roles(:web), :once => true do
      raise "You need to use ruby 1.9 or higher where you are running this capistrano command." unless RUBY_VERSION >= "1.9"
      test "bash", "-l", "-c", "'docker", "ps", "&>", "/dev/null", "||", "sudo", "usermod", "-a", "-G", "docker", "$USER'"
    end
  end

  # do this so capistrano has permissions to remove old releases
  before :updating, :revert_permissions do
    on roles(:web) do
      if test "[", "-d", "#{releases_path}", "]"
        execute "bash", "-l", "-c", "'sudo", "chown", "-R", "deployer.", "#{releases_path}'"
      end
    end
  end

  before :restart, :ensure_permissions do
    on roles(:web) do
      execute "bash", "-l", "-c", "'sudo", "mkdir", "-p", "#{current_path}/data/cache'"
      execute "bash", "-l", "-c", "'sudo", "chown", "-R", "www-data.", "#{current_path}/data'"
    end
  end

  #desc 'Install config files in current_path'
  before :restart, :install_config_files do
    on roles(:web) do |host|
      require 'erb'
      { 'config/nginx.conf.erb'   => "#{current_path}/config/#{fetch(:application)}-nginx.conf",
        'config/php-fpm.conf.erb' => "#{current_path}/config/#{fetch(:application)}-php-fpm.conf",
        'config/php.ini.erb'      => "#{current_path}/config/#{fetch(:application)}-php.ini"
      }.each do |template, upload_path|
        @worker_processes = fetch(:worker_processes)
        template_path = File.expand_path(template)
        host_config   = ERB.new(File.new(template_path).read).result(binding)
        upload! StringIO.new(host_config), upload_path
      end
    end
  end

  desc 'Restart or start application'
  task :restart do
    on roles(:web) do
      ['php5', 'nginx'].each do |name|
        container = {
          :name         => fetch("#{name}_container_name".to_sym),
          :run_options  => fetch("#{name}_run_options".to_sym).join(' '),
          :image        => fetch("#{name}_image_name".to_sym)
        }
        exists      = "docker inspect #{container[:name]} &> /dev/null"
        is_running  = "docker inspect --format='{{.State.Running}}' #{container[:name]} 2>&1 | grep -q true"
        if test(exists)
          if test(is_running)
            execute "docker", "stop", container[:name]
          end
          execute "docker", "rm", container[:name]
        end
        execute(
          "docker", "run",
          "--detach", "--tty",
          "--name", container[:name],
          container[:run_options],
          container[:image]
        )
        sleep 2
        error("Container #{container[:name]} did not stay running more than 2 seconds!") unless test(is_running)
      end
    end
  end

  # :publishing is the hook after which to set our service restart commands
  after :publishing, :restart
end
