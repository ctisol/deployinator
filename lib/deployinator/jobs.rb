namespace :deploy do
  namespace :jobs do

    desc 'Restart jobs using bluepill restart inside the docker container.'
    task :restart => [:install_config_files, 'deploy:check:settings'] do
      on roles(:app) do |host|
        name = fetch(:ruby_jobs_container_name)
        if container_exists?(name)
          if container_is_restarting?(name)
            execute("docker", "stop", name)
          end
          if container_is_running?(name)
            deploy_bluepill_jobs_restart(host)
          else
            execute("docker", "start", name)
          end
        else
          as :root do
            execute("rm", "-f", fetch(:webserver_socket_path).join('jobs.pid'))
          end
          warn "Starting a new container named #{name} on #{host}"
          deploy_run_bluepill_jobs(host)
          check_stayed_running(name)
        end
      end
    end
    after 'deploy:restart', :restart

    desc 'Restart application by recreating the docker container.'
    namespace :restart do
      task :force => [:install_config_files, 'deploy:check:settings'] do
        on roles(:app) do |host|
          name = fetch(:ruby_jobs_container_name)
          if container_exists?(name)
            if container_is_running?(name)
              deploy_bluepill_jobs_stop(host)
              sleep 5
              execute("docker", "stop", name)
              execute("docker", "wait", name)
            else
            end
            begin
              execute("docker", "rm",   name)
            rescue
              sleep 5
              begin
                execute("docker", "rm",   name)
              rescue
                fatal "We were not able to remove the container for some reason. Try running 'cap <stage> deploy:jobs:restart:force' again."
              end
            end
          end
          Rake::Task['deploy:jobs:restart'].invoke
        end
      end
    end

    task :install_config_files do
      on roles(:app) do |host|
        ["bluepill_jobs.rb"].each do |config_file|
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

  end
end
