namespace :deploy do
  namespace :check do

    task :bundle_command_map => ['deployinator:deployment_user'] do
      set :bundle_binstubs, -> { shared_path.join('bundle', 'bin') }
      set :bundle_gemfile,  -> { release_path.join('Gemfile') }
      SSHKit.config.command_map[:bundle] = [
        "/usr/bin/env docker run --rm --tty",
        "--user", fetch(:deployment_user_id),
        "-e", "GEM_HOME=#{shared_path.join('bundle')}",
        "-e", "GEM_PATH=#{shared_path.join('bundle')}",
        "-e", "PATH=#{shared_path.join('bundle', 'bin')}:$PATH",
        "--entrypoint", "#{shared_path.join('bundle', 'bin', 'bundle')}",
        "--volume $SSH_AUTH_SOCK:/ssh-agent --env SSH_AUTH_SOCK=/ssh-agent",
        "--volume #{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
        "--volume /etc/passwd:/etc/passwd:ro",
        "--volume /etc/group:/etc/group:ro",
        "--volume /home:/home:rw",
        fetch(:ruby_image_name)
      ].join(' ')
    end
    before 'bundler:install', 'deploy:check:bundle_command_map'

    # Ensure Capistrano's inner rm commands always run using sudo
    before 'deploy:started', :rm_command_map do
      SSHKit.config.command_map[:rm] = "/usr/bin/env sudo rm"
    end

    if Rake::Task.task_defined?("deploy:cleanup")
      # Append dependancy to existing cleanup task
      task 'deploy:cleanup' => 'deploy:check:rm_command_map'
    end

    desc 'Ensure all deployinator specific settings are set, and warn and raise if not.'
    before 'deploy:check', :settings do
      {
        (File.dirname(__FILE__) + "/examples/config/deploy.rb") => 'config/deploy.rb',
        (File.dirname(__FILE__) + "/examples/config/deploy/staging.rb") => "config/deploy/#{fetch(:stage)}.rb"
      }.each do |abs, rel|
        Rake::Task['deployinator:settings'].invoke(abs, rel)
        Rake::Task['deployinator:settings'].reenable
      end
    end

    # TODO make this better
    before 'deploy:check', :templates do
      run_locally do
        keys_template     = File.expand_path("./templates/deploy/deployment_authorized_keys.erb")
        bluepill_template = File.expand_path("./templates/deploy/bluepill.rb.erb")
        unicorn_template  = File.expand_path("./templates/deploy/unicorn.rb.erb")
        {
          "You need a templates/deploy/deployment_authorized_keys.erb file."          => keys_template,
          "You need a templates/deploy/bluepill.rb.erb file."  => bluepill_template,
          "You need a templates/deploy/unicorn.rb.erb file."   => unicorn_template,
        }.each do |message, file|
          fatal(message) and raise unless File.exists? file
        end
      end
    end

    before 'deploy:check', 'deployinator:deployment_user'
    before 'deploy:check', 'deployinator:webserver_user'

    task :root_dir_permissions => ['deployinator:deployment_user', 'deployinator:webserver_user'] do
      on roles(:app) do
        as :root do
          [fetch(:deploy_to), Pathname.new(fetch(:deploy_to)).join("../")].each do |dir|
            if directory_exists?(dir)
              execute "chown", "#{fetch(:deployment_user_id)}:#{fetch(:webserver_user_id)}", dir
              execute "chmod", "2750", dir
            end
          end
        end
      end
    end
    before 'deploy:check:directories', 'deploy:check:root_dir_permissions'

    before 'deploy:check', :webserver_running do
      on roles(:app) do
        if container_exists?(fetch(:webserver_container_name))
          unless container_is_running?(fetch(:webserver_container_name))
            warn "The webserver container named #{fetch(:webserver_container_name)} exists but is not running. You can still deploy your code, but you need this, start it, or re-run setup with something like nginxinator."
            ask :return_to_continue, nil
            set :nothing, fetch(:return_to_continue)
          end
        else
          warn "No webserver container named #{fetch(:webserver_container_name)} exists! You can still deploy your code, but you need this, set it up with something like nginxinator."
          ask :return_to_continue, nil
          set :nothing, fetch(:return_to_continue)
        end
      end
    end

    before 'deploy:check', :postgres_running do
      on primary fetch(:migration_role) do
        if container_exists?(fetch(:postgres_container_name))
          if container_is_running?(fetch(:postgres_container_name))
            unless localhost_port_responding?(fetch(:postgres_port))
              fatal "Port #{fetch(:postgres_port)} is not responding, we won't be able to db:migrate!"
              raise
            end
          else
            fatal "#{fetch(:postgres_container_name)} exists but is not running, we won't be able to db:migrate!"
            raise
          end
        else
          fatal "#{fetch(:postgres_container_name)} does not exist, we won't be able to db:migrate!"
          raise
        end
      end
    end

    before 'deploy:check', :ensure_cadvisor do
      on roles(:app), in: :sequence, wait: 5 do
        if fetch(:use_cadvisor, true)
          if container_exists?("cadvisor")
            if container_is_running?("cadvisor")
              info "cadvisor is already running."
            else
              info "Restarting existing cadvisor container."
              execute "docker", "start", "cadvisor"
            end
          else
            execute("docker", "run", fetch(:docker_run_cadvisor_command))
          end
        else
          info "Not using cadvisor."
        end
      end
    end

  end
end
