namespace :deploy do
  namespace :jobs do

    desc 'Restart jobs using bluepill restart inside the docker container.'
    task :restart => ['deployinator:load_settings', 'deploy:check:settings'] do
      on roles(:app) do |host|
        name = fetch(:ruby_jobs_container_name)
        if container_exists?(name)
          if container_is_restarting?(name)
            execute("docker", "stop", name)
          end
          if container_is_running?(name)
            restart_container(fetch(:ruby_jobs_container_name))
          else
            start_container(name)
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
      task :force => ['deployinator:load_settings', 'deploy:check:settings'] do
        on roles(:app) do |host|
          name = fetch(:ruby_jobs_container_name)
          if container_exists?(name)
            if container_is_running?(name)
              execute("docker", "stop", name)
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

  end
end
