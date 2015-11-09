# config valid only for Capistrano 3.1
lock '3.2.1'

namespace :deploy do

  before :starting, 'deployinator:sshkit_umask'

  # Default branch is :master
  before :starting, :set_branch do
    unless ENV['from_local']
      # Always use the master branch in production:
      unless "#{fetch(:stage)}" == "production"
        ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call
      end
    end
  end

  #desc 'Copies .git folder to support .gemspecs that run git commands'
  task :copy_git do
    unless ENV['from_local'] == "true"
      on roles(:app) do
        within release_path do
          execute :cp, '-r', repo_path, '.git'
        end
      end
    end
  end
  before 'bundler:install', 'deploy:copy_git'

  if Rake::Task.task_defined?("deploy:assets:precompile")
    # Overwrite :assets:precompile to use docker
    Rake::Task["deploy:assets:precompile"].clear_actions
    namespace :assets do
      task :precompile do
        on roles(fetch(:assets_roles)) do |host|
          deploy_assets_precompile(host)
        end
      end
    end
  end

  if Rake::Task.task_defined?("deploy:cleanup_assets")
    # Overwrite :cleanup_assets to use docker
    Rake::Task["deploy:cleanup_assets"].clear_actions
    desc 'Cleanup expired assets'
    task :cleanup_assets => [:set_rails_env] do
      on roles(fetch(:assets_roles)) do |host|
        deploy_assets_cleanup(host)
      end
    end
  end

  if Rake::Task.task_defined?("deploy:migrate")
    # Overwrite :migrate to use docker
    Rake::Task["deploy:migrate"].clear_actions
    desc 'Runs rake db:migrate if migrations are set'
    task :migrate => [:set_rails_env, 'deploy:check:postgres_running'] do
      on primary fetch(:migration_role) do |host|
        conditionally_migrate = fetch(:conditionally_migrate)
        info '[deploy:migrate] Checking changes in /db/migrate' if conditionally_migrate
        if conditionally_migrate && test("diff -q #{release_path}/db/migrate #{current_path}/db/migrate")
          info '[deploy:migrate] Skip `deploy:migrate` (nothing changed in db/migrate)'
        else
          info '[deploy:migrate] Run `rake db:migrate`' if conditionally_migrate
          deploy_rake_db_migrate(host)
        end
      end
    end
  end

  task :install_bundler do
    on roles(:app) do |host|
      unless file_exists?(shared_path.join('bundle', 'bin', 'bundle'))
        deploy_install_bundler(host)
      end
    end
  end
  before 'bundler:install', 'deploy:install_bundler'

  desc 'Restart application using bluepill restart inside the docker container.'
  task :restart => [:install_config_files, 'deploy:check:settings'] do
    on roles(:app) do |host|
      name = fetch(:ruby_container_name)
      if container_exists?(name)
        if container_is_restarting?(name)
          execute("docker", "stop", name)
        end
        if container_is_running?(name)
          deploy_bluepill_restart(host)
        else
          execute("docker", "start", name)
        end
      else
        as :root do
          execute("rm", "-f", fetch(:webserver_socket_path).join('unicorn.pid'))
        end
        warn "Starting a new container named #{name} on #{host}"
        deploy_run_bluepill(host)
        check_stayed_running(name)
      end
    end
  end
  after :publishing, :restart

  desc 'Restart application by recreating the docker container.'
  namespace :restart do
    task :force => [:install_config_files, 'deploy:check:settings'] do
      on roles(:app) do |host|
        name = fetch(:ruby_container_name)
        if container_exists?(name)
          if container_is_running?(name)
            deploy_bluepill_stop(host)
            sleep 5
            execute("docker", "stop", name)
            execute("docker", "wait", name)
          end
          begin
            execute("docker", "rm",   name)
          rescue
            sleep 5
            begin
              execute("docker", "rm",   name)
            rescue
              fatal "We were not able to remove the container for some reason. Try running 'cap <stage> deploy:restart:force' again."
            end
          end
        end
        Rake::Task['deploy:restart'].invoke
      end
    end
  end

#  after :restart, :clear_cache do
#    on roles(:web), in: :groups, limit: 3, wait: 10 do
#      # Here we can do anything such as:
#      # within release_path do
#      #   execute :rake, 'cache:clear'
#      # end
#    end
#  end

  task :install_config_files do
    on roles(:app) do |host|
      ["bluepill.rb", "unicorn.rb"].each do |config_file|
        template_path = File.expand_path("./#{fetch(:deploy_templates_path)}/#{config_file}.erb")
        generated_config_file = ERB.new(File.new(template_path).read).result(binding)
        set :final_path, -> { release_path.join('config', config_file) }
        upload! StringIO.new(generated_config_file), "/tmp/#{config_file}"
        execute("mv", "/tmp/#{config_file}", fetch(:final_path))
        as :root do
          execute("chown", "#{fetch(:deployment_username)}:#{fetch(:webserver_username)}", fetch(:final_path))
        end
      end
    end
  end

  desc "Enter the Rails console."
  task :rails_console do
    on roles(:app) do |host|
      info "Entering Rails Console inside #{fetch(:ruby_container_name)} on #{host}"
      system deploy_rails_console(host)
    end
  end

  namespace :rails_console do
    task :print do
      on roles(:app) do |host|
        info "You can SSH into #{host} and run the following command to enter the Rails Console."
        info deploy_rails_console_print(host)
      end
    end
  end

  desc "Write Version file on server"
  after 'deploy:finished', :write_version_file do
    on roles(:app) do |host|
      execute "echo", "\"<version>", "<release>#{fetch(:current_revision)}</release>",
        "<deployed_at>#{Time.now.strftime('%m/%d/%Y at %H:%M %Z')}</deployed_at>",
        "<branch>#{fetch(:branch)}</branch>",
        "</version>\"", ">", current_path.join('public', 'version.xml')
    end
  end

  after 'deploy:finished', :success_message do
    run_locally do
      info "That was a successful deploy!"
    end
  end

end
