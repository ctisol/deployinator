namespace :deploy do
  namespace :check do

    task :bundle_command_map => ['deployinator:deployment_user'] do
      set :bundle_binstubs, -> { shared_path.join('bundle', 'bin') }
      set :bundle_gemfile,  -> { release_path.join('Gemfile') }
      SSHKit.config.command_map[:bundle] = sshkit_bundle_command_map
    end
    before 'bundler:install', 'deploy:check:bundle_command_map'

    # Ensure Capistrano's inner rm commands always run using sudo
    before 'deploy:started', :rm_command_map do
      SSHKit.config.command_map[:rm] = "/usr/bin/env sudo rm"
    end

    before 'deploy:check', :brakeman_reminder do
      run_locally do
        warn "Remember to run brakeman before deploying!"
        ask :return_to_continue, nil
        set :nothing, fetch(:return_to_continue)
      end
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
        keys_template     = File.expand_path("./#{fetch(:deploy_templates_path)}/deployment_authorized_keys.erb")
        bluepill_template = File.expand_path("./#{fetch(:deploy_templates_path)}/bluepill.rb.erb")
        unicorn_template  = File.expand_path("./#{fetch(:deploy_templates_path)}/unicorn.rb.erb")
        {
          "You need a #{fetch(:deploy_templates_path)}/deployment_authorized_keys.erb file."          => keys_template,
          "You need a #{fetch(:deploy_templates_path)}/bluepill.rb.erb file."  => bluepill_template,
          "You need a #{fetch(:deploy_templates_path)}/unicorn.rb.erb file."   => unicorn_template,
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
          [fetch(:deploy_to), Pathname.new(fetch(:deploy_to)).join("../"), shared_path].each do |dir|
            if directory_exists?(dir)
              execute "chown", "#{fetch(:deployment_username)}:#{fetch(:webserver_username)}", dir
              execute "chmod", "2750", dir
            end
          end
        end
      end
    end
    before 'deploy:check:directories', 'deploy:check:root_dir_permissions'

    before 'deploy:check', :postgres_running do
      on roles(:app) do
        unless localhost_port_responding?(fetch(:postgres_port))
          fatal "Port #{fetch(:postgres_port)} is not responding, we won't be able to db:migrate!"
          raise
        end
      end
    end

    before 'deploy:check', :ensure_cadvisor do
      on roles(:app) do |host|
        if fetch(:use_cadvisor, true)
          if container_exists?("cadvisor")
            if container_is_running?("cadvisor")
              info "cadvisor is already running."
            else
              info "Starting existing cadvisor container."
              start_container("cadvisor")
            end
          else
            warn "Starting a new container named 'cadvisor' on #{host}"
            deploy_run_cadvisor(host)
            check_stayed_running("cadvisor")
          end
        else
          info "Not using cadvisor."
        end
      end
    end

  end
end
