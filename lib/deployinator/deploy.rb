# config valid only for Capistrano 3.1
lock '3.2.1'

namespace :deploy do

  task :set_bundle_command_map => [:set_deployer_user_id] do
    SSHKit.config.command_map[:bundle] = [
      "/usr/bin/env docker run --rm --tty",
      "--user", fetch(:deployer_user_id),
      "-e", "GEM_HOME=#{fetch(:deploy_to)}/shared/bundle",
      "-e", "GEM_PATH=#{fetch(:deploy_to)}/shared/bundle",
      "-e", "PATH=#{fetch(:deploy_to)}/shared/bundle/bin:$PATH",
      "--entrypoint", "#{fetch(:deploy_to)}/shared/bundle/bin/bundle",
      "--volume $SSH_AUTH_SOCK:/ssh-agent --env SSH_AUTH_SOCK=/ssh-agent",
      "--volume #{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
      "--volume /etc/passwd:/etc/passwd:ro",
      "--volume /etc/group:/etc/group:ro",
      "--volume /home:/home:rw",
      fetch(:ruby_image_name)
    ].join(' ')
  end
  before 'bundler:install', 'deploy:set_bundle_command_map'

  task :set_rm_command_map do
    SSHKit.config.command_map[:rm] = "/usr/bin/env sudo rm"
  end
  before 'deploy:started', 'deploy:set_rm_command_map'

  # Append dependancy to existing cleanup task
  task :cleanup => :set_rm_command_map

  # If defined, overwrite :assets:precompile to use docker
  if Rake::Task.task_defined?("deploy:assets:precompile")
    Rake::Task["deploy:assets:precompile"].clear
    namespace :assets do
      task :precompile do
        on roles(fetch(:assets_roles)) do
          execute(
            "docker", "run", "--rm", "--tty",
            "-w", fetch(:release_path, "#{fetch(:deploy_to)}/current"),
            "--link", "#{fetch(:postgres_container_name)}:postgres",
            "--entrypoint", "#{fetch(:deploy_to)}/shared/bundle/bin/rake",
            "--volume", "#{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
            fetch(:ruby_image_name), "assets:precompile"
          )
        end
      end
    end
  end

  # If defined, overwrite :cleanup_assets to use docker
  if Rake::Task.task_defined?("deploy:cleanup_assets")
    Rake::Task["deploy:cleanup_assets"].clear
    desc 'Cleanup expired assets'
    task :cleanup_assets => [:set_rails_env] do
      on roles(fetch(:assets_roles)) do
        execute(
          "docker", "run", "--rm", "--tty",
          "-e", "RAILS_ENV=#{fetch(:rails_env)}",
          "-w", fetch(:release_path, "#{fetch(:deploy_to)}/current"),
          "--entrypoint", "#{fetch(:deploy_to)}/shared/bundle/bin/bundle",
          "--volume", "#{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
          fetch(:ruby_image_name), "exec", "rake", "assets:clean"
        )
      end
    end
  end

  # If defined, overwrite :migrate to use docker
  if Rake::Task.task_defined?("deploy:migrate")
    Rake::Task["deploy:migrate"].clear
    desc 'Runs rake db:migrate if migrations are set'
    task :migrate => [:set_rails_env, :ensure_running_postgres] do
      on primary fetch(:migration_role) do
        conditionally_migrate = fetch(:conditionally_migrate)
        info '[deploy:migrate] Checking changes in /db/migrate' if conditionally_migrate
        if conditionally_migrate && test("diff -q #{release_path}/db/migrate #{current_path}/db/migrate")
          info '[deploy:migrate] Skip `deploy:migrate` (nothing changed in db/migrate)'
        else
          info '[deploy:migrate] Run `rake db:migrate`' if conditionally_migrate
          execute(
            "docker", "run", "--rm", "--tty",
            "--link", "#{fetch(:postgres_container_name)}:postgres",
            "--volume", "#{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
            "-e", "RAILS_ENV=#{fetch(:rails_env)}",
            "--entrypoint", "#{fetch(:deploy_to)}/shared/bundle/bin/rake",
            "-w", fetch(:release_path, "#{fetch(:deploy_to)}/current"),
            fetch(:ruby_image_name), "db:migrate"
          )
        end
      end
    end
  end

  # TODO make this better
  task :ensure_running_postgres do
    on primary fetch(:migration_role) do
      unless capture("nc", "127.0.0.1", fetch(:postgres_port), "<", "/dev/null", ">", "/dev/null;", "echo", "$?").strip == "0"
        fatal "Port #{fetch(:postgres_port)} is not responding, cannot db:migrate!"
        raise
      end
    end
  end
#  task :ensure_running_postgres do
#    on primary fetch(:migration_role) do
#      if test "docker", "inspect", fetch(:postgres_container_name), "&>", "/dev/null"
#        if (capture "docker", "inspect",
#            "--format='{{.State.Running}}'",
#            fetch(:postgres_container_name)).strip == "true"
#        else
#          execute "docker", "start", fetch(:postgres_container_name)
#        end
#      else
#        set :run_pg_setup, ask("'true' or 'false', - #{fetch(:postgres_container_name)} is not running, would you like to run 'rake pg:setup'?", "false")
#        if fetch(:run_pg_setup) == "true"
#          #load Gem.bin_path('bundler', 'bundle')
#          #import 'postgresinator'
#          #load './infrastructure/Rakefile'
#          Rake::Task['pg:setup'].invoke
#        else
#          raise "#{fetch(:postgres_container_name)} is not running, can't run db:migrate!"
#        end
#      end
#    end
#  end
  before 'deploy:started', :ensure_running_postgres

  before 'deploy:check', :setup_deployer_user do
    on "#{ENV['USER']}@#{fetch(:domain)}" do
      as :root do
        unless test "id", fetch(:deploy_username)
          execute "adduser", "--disabled-password", "--gecos", "\"\"", fetch(:deploy_username)
          execute "usermod", "-a", "-G", "sudo", fetch(:deploy_username)
          execute "usermod", "-a", "-G", "docker", fetch(:deploy_username)
        end
        execute "mkdir", "-p", "/home/#{fetch(:deploy_username)}/.ssh"
        # not actually using ERB interpolation, no need for an instance variable.
        template_path = File.expand_path("./templates/deploy/#{fetch(:deploy_username)}_authorized_keys.erb")
        generated_config_file = ERB.new(File.new(template_path).read).result(binding)
        # upload! does not yet honor "as" and similar scoping methods
        upload! StringIO.new(generated_config_file), "/tmp/authorized_keys"
        execute "mv", "-b", "/tmp/authorized_keys", "/home/#{fetch(:deploy_username)}/.ssh/authorized_keys"
        execute "chown", "-R", "#{fetch(:deploy_username)}:#{fetch(:deploy_username)}", "/home/#{fetch(:deploy_username)}/.ssh"
        execute "chmod", "700", "/home/#{fetch(:deploy_username)}/.ssh"
        execute "chmod", "600", "/home/#{fetch(:deploy_username)}/.ssh/authorized_keys"
      end
    end
  end

  task :ensure_www_data_user do
    on "#{ENV['USER']}@#{fetch(:domain)}" do
      as :root do
        unless test "id", "www-data"
          execute "adduser", "--disabled-password", "--gecos", "\"\"", "www-data"
        end
      end
    end
  end
  after 'deploy:started', :ensure_www_data_user

  task :set_deployer_user_id do
    on roles(:app), in: :sequence, wait: 5 do
      set :deployer_user_id, capture("id", "-u", fetch(:deploy_username)).strip
    end
  end

  task :set_www_data_user_id do
    on roles(:app), in: :sequence, wait: 5 do
      set :www_data_user_id, capture("id", "-u", "www-data").strip
    end
  end

  task :chown_log_dir => :set_www_data_user_id do
    on roles(:app), in: :sequence, wait: 5 do
      as :root do
        unless test "[", "-d", "#{fetch(:deploy_to)}/shared/log", "]"
          execute("mkdir", "-p", "#{fetch(:deploy_to)}/shared/log")
        end
        execute "chown", "-R", "#{fetch(:www_data_user_id)}:#{fetch(:www_data_user_id)}", "#{fetch(:deploy_to)}/shared/log"
      end
    end
  end
  before 'deploy:check:linked_dirs', :chown_log_dir

  task :setup_deploy_to_dir => :set_deployer_user_id do
    on roles(:app), in: :sequence, wait: 5 do
      as :root do
        [
          fetch(:deploy_to),
          "#{fetch(:deploy_to)}/shared",
          "#{fetch(:deploy_to)}/releases"
        ].each do |dir|
          unless test "[", "-d", dir, "]"
            execute("mkdir", "-p", dir)
          end
          execute "chown", "#{fetch(:deployer_user_id)}:#{fetch(:deployer_user_id)}", dir
        end
      end
    end
  end
  after :setup_deployer_user, :setup_deploy_to_dir

  task :install_bundler => :set_deployer_user_id do
    on roles(:app), in: :sequence, wait: 5 do
      as :root do
        unless test "[", "-f", "#{fetch(:deploy_to)}/shared/bundle/bin/bundle", "]"
          execute(
            "docker", "run", "--rm", "--tty",
            "-e", "GEM_HOME=#{fetch(:deploy_to)}/shared/bundle",
            "-e", "GEM_PATH=#{fetch(:deploy_to)}/shared/bundle",
            "-e", "PATH=#{fetch(:deploy_to)}/shared/bundle/bin:$PATH",
            "--entrypoint", "/usr/local/bin/gem",
            "--volume", "#{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
            fetch(:ruby_image_name), "install",
            "--install-dir", "#{fetch(:deploy_to)}/shared/bundle",
            "--bindir", "#{fetch(:deploy_to)}/shared/bundle/bin",
            "--no-ri", "--no-rdoc", "--quiet", "bundler", "-v'#{fetch(:bundler_version)}'"
          )
        end
        execute "chown", "-R", "#{fetch(:deployer_user_id)}:#{fetch(:deployer_user_id)}", "#{fetch(:deploy_to)}/shared/bundle"
      end
    end
  end
  before 'bundler:install', 'deploy:install_bundler'

  desc 'Restart application using bluepill restart inside the docker container.'
  task :restart => [:set_www_data_user_id, :install_config_files] do
    on roles(:app), in: :sequence, wait: 5 do
      as :root do
        paths = [
          fetch(:external_socket_path),
          "#{fetch(:deploy_to)}/current/public",
          "#{fetch(:deploy_to)}/shared/tmp",
          "#{fetch(:deploy_to)}/shared/log/production.log"
        ].join(' ')
        execute "chown", "-R", "#{fetch(:www_data_user_id)}:#{fetch(:www_data_user_id)}", paths
      end
      if test "docker", "inspect", fetch(:ruby_container_name), "&>", "/dev/null"
        if (capture "docker", "inspect",
            "--format='{{.State.Restarting}}'",
            fetch(:ruby_container_name)).strip == "true"
          execute("docker", "stop", fetch(:ruby_container_name))
        end
        if (capture "docker", "inspect",
            "--format='{{.State.Running}}'",
            fetch(:ruby_container_name)).strip == "true"
          execute(
            "docker", "exec", "--tty",
            fetch(:ruby_container_name),
            "#{fetch(:deploy_to)}/shared/bundle/bin/bluepill",
            fetch(:application), "restart"
          )
        end
      else
        as :root do
          execute("rm", "-f", "#{fetch(:external_socket_path)}/unicorn.pid")
g         execute "chown", "-R", "#{fetch(:deployer_user_id)}:#{fetch(:deployer_user_id)}", "#{fetch(:deploy_to)}/shared/bundle"
        end
        execute("docker", "run", fetch(:docker_run_bluepill_command))
      end
    end
  end
  after :publishing, :restart

  desc 'Restart application by recreating the docker container.'
  namespace :restart do
    task :force do
      on roles(:app), in: :sequence, wait: 5 do
        if (capture "docker", "inspect",
            "--format='{{.State.Running}}'",
            fetch(:ruby_container_name)).strip == "true"
          execute(
            "docker", "exec", "--tty",
            fetch(:ruby_container_name),
            "#{fetch(:deploy_to)}/shared/bundle/bin/bluepill",
            fetch(:application), "stop"
          )
          sleep 5
        end
        execute("docker", "stop", fetch(:ruby_container_name))
        execute("docker", "wait", fetch(:ruby_container_name))
        begin
          execute("docker", "rm",   fetch(:ruby_container_name))
        rescue
          sleep 5
          begin
            execute("docker", "rm",   fetch(:ruby_container_name))
          rescue
            fatal "We were not able to remove the container for some reason. Try running 'cap <stage> deploy:restart:force' again."
          end
        end
        Rake::Task['deploy:restart'].invoke
      end
    end
  end

  after :publishing, :check_nginx_running do
    on primary fetch(:migration_role) do
      # TODO fix false negative when nginx_container_name is unset
      if test "docker", "inspect", fetch(:nginx_container_name), "&>", "/dev/null"
        if (capture "docker", "inspect",
            "--format='{{.State.Running}}'",
            fetch(:nginx_container_name)).strip == "true"
        else
          warn "The nginx container named #{fetch(:nginx_container_name)} exists but is not running. (You need this, start it, or re-run setup with something like nginxinator.)"
        end
      else
        warn "No nginx container named #{fetch(:nginx_container_name)} exists! (You need this, set it up with something like nginxinator.)"
      end
    end
  end

  after :publishing, :ensure_cadvisor do
    on roles(:app), in: :sequence, wait: 5 do
      if fetch(:use_cadvisor, true)
        if test "docker", "inspect", "cadvisor", "&>", "/dev/null"
          if (capture "docker", "inspect",
              "--format='{{.State.Running}}'",
              "cadvisor").strip == "true"
            info "cadvisor is already running."
          else
            info "Restarting existing cadvisor container."
            execute "docker", "start", "cadvisor"
          end
        else
          execute("docker", "run", fetch(:docker_run_cadvisor_command))
        end
      end
    end
  end

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

  task :install_config_files => [:set_deployer_user_id] do
    on roles(:app), in: :sequence, wait: 5 do
      set :bluepill_config, -> { "#{fetch(:application)}_bluepill.rb" }
      set :unicorn_config,  -> { "#{fetch(:application)}_unicorn.rb" }
      set :socket_path,     -> { fetch(:internal_socket_path) }
      as 'root' do
        [fetch(:bluepill_config), fetch(:unicorn_config)].each do |config_file|
          @deploy_to            = fetch(:deploy_to)   # needed for ERB
          @internal_socket_path = fetch(:socket_path) # needed for ERB
          @application          = fetch(:application) # needed for ERB
          template_path = File.expand_path("./templates/deploy/#{config_file}.erb")
          current_path  = Pathname.new("#{fetch(:deploy_to)}/current")
          generated_config_file = ERB.new(File.new(template_path).read).result(binding)
          set :final_path, -> { fetch(:release_path, current_path).join('config', config_file) }
          upload! StringIO.new(generated_config_file), "/tmp/#{config_file}"
          execute("mv", "/tmp/#{config_file}", fetch(:final_path))
          execute("chown", "#{fetch(:deployer_user_id)}:#{fetch(:deployer_user_id)}", fetch(:final_path))
          execute("chmod", "664", fetch(:final_path))
        end
      end
    end
  end

end
