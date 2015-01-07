# config valid only for Capistrano 3.1
lock '3.2.1'

namespace :deploy do

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
    Rake::Task["deploy:assets:precompile"].clear
    namespace :assets do
      task :precompile => ['deployinator:deployment_user'] do
        on roles(fetch(:assets_roles)) do
          execute(
            "docker", "run", "--rm", "--tty", "--user", fetch(:webserver_username),
            "-w", release_path,
            "--link", "#{fetch(:postgres_container_name)}:postgres",
            "--entrypoint", "/bin/bash",
            "--volume", "/etc/passwd:/etc/passwd:ro",
            "--volume", "/etc/group:/etc/group:ro",
            "--volume", "#{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
            fetch(:ruby_image_name), "-c",
            "\"umask", "0007", "&&", "#{shared_path.join('bundle', 'bin', 'rake')}",
            "assets:precompile\""
          )
        end
      end
    end
  end

  if Rake::Task.task_defined?("deploy:cleanup_assets")
    # Overwrite :cleanup_assets to use docker
    Rake::Task["deploy:cleanup_assets"].clear
    desc 'Cleanup expired assets'
    task :cleanup_assets => [:set_rails_env] do
      on roles(fetch(:assets_roles)) do
        execute(
          "docker", "run", "--rm", "--tty",
          "-e", "RAILS_ENV=#{fetch(:rails_env)}",
          "-w", release_path,
          "--entrypoint", shared_path.join('bundle', 'bin', 'bundle'),
          "--volume", "#{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
          fetch(:ruby_image_name), "exec", "rake", "assets:clean"
        )
      end
    end
  end

  if Rake::Task.task_defined?("deploy:migrate")
    # Overwrite :migrate to use docker
    Rake::Task["deploy:migrate"].clear
    desc 'Runs rake db:migrate if migrations are set'
    task :migrate => [:set_rails_env, 'deploy:check:postgres_running'] do
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
            "--entrypoint", shared_path.join('bundle', 'bin', 'rake'),
            "-w", release_path,
            fetch(:ruby_image_name), "db:migrate"
          )
        end
      end
    end
  end

  task :install_bundler => ['deployinator:deployment_user'] do
    on roles(:app), in: :sequence, wait: 5 do
      unless file_exists?(shared_path.join('bundle', 'bin', 'bundle'))
        execute(
          "docker", "run", "--rm", "--tty", "--user", fetch(:deployment_user_id),
          "-e", "GEM_HOME=#{shared_path.join('bundle')}",
          "-e", "GEM_PATH=#{shared_path.join('bundle')}",
          "-e", "PATH=#{shared_path.join('bundle', 'bin')}:$PATH",
          "--entrypoint", "/bin/bash",
          "--volume", "#{fetch(:deploy_to)}:#{fetch(:deploy_to)}:rw",
          fetch(:ruby_image_name), "-c",
          "\"umask", "0007", "&&" "/usr/local/bin/gem", "install",
          "--install-dir", "#{shared_path.join('bundle')}",
          "--bindir", shared_path.join('bundle', 'bin'),
          "--no-ri", "--no-rdoc", "--quiet", "bundler", "-v'#{fetch(:bundler_version)}'\""
        )
      end
    end
  end
  before 'bundler:install', 'deploy:install_bundler'

  desc 'Restart application using bluepill restart inside the docker container.'
  task :restart => ['deployinator:webserver_user', :install_config_files] do
    on roles(:app), in: :sequence, wait: 5 do
      if container_exists?(fetch(:ruby_container_name))
        if container_is_restarting?(fetch(:ruby_container_name))
          execute("docker", "stop", fetch(:ruby_container_name))
        end
        if container_is_running?(fetch(:ruby_container_name))
          execute(
            "docker", "exec", "--tty",
            fetch(:ruby_container_name),
            shared_path.join('bundle', 'bin', 'bluepill'),
            fetch(:application), "restart"
          )
        else
          execute("docker", "start", fetch(:ruby_container_name))
        end
      else
        as :root do
          execute("rm", "-f", fetch(:webserver_socket_path).join('unicorn.pid'))
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
        if container_exists?(fetch(:ruby_container_name))
          if container_is_running?(fetch(:ruby_container_name))
            execute(
              "docker", "exec", "--tty",
              fetch(:ruby_container_name),
              shared_path.join('bundle', 'bin', 'bluepill'),
              fetch(:application), "stop"
            )
            sleep 5
            execute("docker", "stop", fetch(:ruby_container_name))
            execute("docker", "wait", fetch(:ruby_container_name))
          else
          end
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

  task :install_config_files => ['deployinator:deployment_user', 'deployinator:webserver_user'] do
    on roles(:app), in: :sequence, wait: 5 do
      set :bluepill_config, -> { "bluepill.rb" }
      set :unicorn_config,  -> { "unicorn.rb" }
      set :socket_path,     -> { fetch(:webserver_socket_path) }
      [fetch(:bluepill_config), fetch(:unicorn_config)].each do |config_file|
        template_path = File.expand_path("./templates/deploy/#{config_file}.erb")
        generated_config_file = ERB.new(File.new(template_path).read).result(binding)
        set :final_path, -> { release_path.join('config', config_file) }
        upload! StringIO.new(generated_config_file), "/tmp/#{config_file}"
        execute("mv", "/tmp/#{config_file}", fetch(:final_path))
        as :root do
          execute("chown", "#{fetch(:deployment_user_id)}:#{fetch(:webserver_user_id)}", fetch(:final_path))
        end
      end
    end
  end

  task :print_rails_console do
    run_locally do
      command = [
        "docker", "exec", "--interactive", "--tty",
        fetch(:ruby_container_name),
        "bash", "-c", "\"cd", current_path, "&&",
        shared_path.join('bundle', 'bin', 'rails'),
        "console", "#{fetch(:rails_env)}\""
      ].join(' ')
      info command
    end
  end

  after 'deploy:finished', :success_message do
    run_locally do
      info "That was a successful deploy!"
    end
  end

end
