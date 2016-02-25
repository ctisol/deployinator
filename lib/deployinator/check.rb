namespace :deploy do
  namespace :check do

    task :bundle_command_map => 'deployinator:load_settings' do
      set :bundle_binstubs, -> { shared_path.join('bundle', 'bin') }
      set :bundle_gemfile,  -> { release_path.join('Gemfile') }
      SSHKit.config.command_map[:bundle] = sshkit_bundle_command_map
    end
    if Rake::Task.task_defined?("bundler:install")
      before 'bundler:install', 'deploy:check:bundle_command_map'
    end

    # Ensure Capistrano's inner rm commands always run using sudo
    task :rm_command_map => 'deployinator:load_settings' do
      SSHKit.config.command_map[:rm] = "/usr/bin/env sudo rm"
    end
    before 'deploy:started', 'deploy:check:rm_command_map'
    if Rake::Task.task_defined?("deploy:cleanup")
      # Append dependancy to existing cleanup task
      task 'deploy:cleanup' => 'deploy:check:rm_command_map'
    end

    desc 'Ensure all deployinator specific settings are set, and warn and raise if not.'
    task :settings => 'deployinator:load_settings' do
      {
        (File.dirname(__FILE__) + "/examples/config/deploy.rb") => 'config/deploy.rb',
        (File.dirname(__FILE__) + "/examples/config/deploy/staging.rb") => "config/deploy/#{fetch(:stage)}.rb"
      }.each do |abs, rel|
        Rake::Task['deployinator:settings'].invoke(abs, rel)
        Rake::Task['deployinator:settings'].reenable
      end
    end
    before 'deploy:check', 'deploy:check:settings'

    # TODO make this better
    task :templates => 'deployinator:load_settings' do
      run_locally do
        path = fetch(:deploy_templates_path)
        keys_template          = File.expand_path("./#{path}/deployment_authorized_keys.erb")
        bluepill_template      = File.expand_path("./#{path}/bluepill.rb.erb")
        unicorn_template       = File.expand_path("./#{path}/unicorn.rb.erb")
        templates = [keys_template, bluepill_template, unicorn_template]
        templates.each do |file|
          fatal("You need a #{file} template file.") and raise unless File.exists? file
        end
      end
    end
    before 'deploy:check', 'deploy:check:templates'

    task :root_dir_permissions => ['deployinator:load_settings', 'deployinator:deployment_user', 'deployinator:webserver_user'] do
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

    task :postgres_running => 'deployinator:load_settings' do
      on roles(:app) do
        unless localhost_port_responding?(fetch(:postgres_port))
          fatal "Port #{fetch(:postgres_port)} is not responding, we won't be able to db:migrate!"
          raise
        end
      end
    end
    before 'deploy:check', 'deploy:check:postgres_running'

    task :ensure_cadvisor => 'deployinator:load_settings' do
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
    before 'deploy:check', 'deploy:check:ensure_cadvisor'

  end
end
