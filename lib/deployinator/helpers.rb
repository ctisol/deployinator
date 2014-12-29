namespace :deployinator do

  # These are the only two tasks using :preexisting_ssh_user
  namespace :deployment_user do
    #desc "Setup or re-setup the deployment user, idempotently"
    task :setup do
      on "#{fetch(:preexisting_ssh_user)}@#{fetch(:domain)}" do
        as :root do
          unix_user_add(fetch(:deployment_username)) unless unix_user_exists?(fetch(:deployment_username))
          execute "usermod", "-a", "-G", "sudo,docker,#{fetch(:webserver_username)}", fetch(:deployment_username)
          execute "mkdir", "-p", "/home/#{fetch(:deployment_username)}/.ssh"
          template_path = File.expand_path("./templates/deploy/deployment_authorized_keys.erb")
          generated_config_file = ERB.new(File.new(template_path).read).result(binding)
          # upload! does not yet honor "as" and similar scoping methods
          upload! StringIO.new(generated_config_file), "/tmp/authorized_keys"
          execute "mv", "-b", "/tmp/authorized_keys", "/home/#{fetch(:deployment_username)}/.ssh/authorized_keys"
          execute "chown", "-R", "#{fetch(:deployment_username)}:#{fetch(:deployment_username)}", "/home/#{fetch(:deployment_username)}/.ssh"
          execute "chmod", "700", "/home/#{fetch(:deployment_username)}/.ssh"
          execute "chmod", "600", "/home/#{fetch(:deployment_username)}/.ssh/authorized_keys"
        end
      end
    end
  end

  task :deployment_user do
    on "#{fetch(:preexisting_ssh_user)}@#{fetch(:domain)}" do
      as :root do
        if unix_user_exists?(fetch(:deployment_username))
          info "User #{fetch(:deployment_username)} already exists. You can safely re-setup the user with 'deployinator:deployment_user:setup'."
        else
          Rake::Task['deployinator:deployment_user:setup'].invoke
        end
        set :deployment_user_id, unix_user_get_id(fetch(:deployment_username))
      end
    end
  end

  task :webserver_user do
    on roles(:app) do
      as :root do
        unix_user_add(fetch(:webserver_username)) unless unix_user_exists?(fetch(:webserver_username))
        set :webserver_user_id, unix_user_get_id(fetch(:webserver_username))
      end
    end
  end

  task :sshkit_umask do
    SSHKit.config.umask = "0027"
  end
  if Rake::Task.task_defined?('deploy:started')
    before 'deploy:started', 'deployinator:sshkit_umask'
  end

  task :file_permissions => [:deployment_user, :webserver_user] do
    on roles(:app) do
      as :root do
        ignore_options = fetch(:ignore_permissions_dirs).collect do |dir|
          ["-not", "-path", "\"#{dir}\"", "-not", "-path", "\"#{dir}/*\""]
        end

        # chown
        execute "find", fetch(:deploy_to), ignore_options,
          "-exec", "chown", "#{fetch(:deployment_user_id)}:#{fetch(:webserver_user_id)}", "{}", "+"

        # chmod executable
        fetch(:webserver_executable_dirs).each do |dir|
          if directory_exists?(dir)
            execute "find", dir, "-type", "f",
              "-exec", "chmod", "0750", "{}", "+"
          end
          ignore_options += ["-not", "-path", "\"#{dir}\"", "-not", "-path", "\"#{dir}/*\""]
        end

        # chmod writable
        fetch(:webserver_writeable_dirs).each do |dir|
          if directory_exists?(dir)
            execute "find", "-L", dir, "-type", "d",
              "-exec", "chmod", "2770", "{}", "+"
            execute "find", "-L", dir, "-type", "f",
              "-exec", "chmod", "0660", "{}", "+"
          end
          ignore_options += ["-not", "-path", "\"#{dir}\"", "-not", "-path", "\"#{dir}/*\""]
        end

        # chmod
        execute "find", fetch(:deploy_to), "-type", "d", ignore_options,
          "-exec", "chmod", "2750", "{}", "+"
        execute "find", fetch(:deploy_to), "-type", "f", ignore_options,
          "-exec", "chmod", "0640", "{}", "+"
      end
    end
  end
  after   'deploy:check',   'deployinator:file_permissions'
  before  'deploy:restart', 'deployinator:file_permissions'


  task :settings, [:absolute_path, :relative_path] do |t, args|
    run_locally do
      need_moar_settings = false
      settings = File.read(args.absolute_path).split("\nset").collect do |line|
        "set#{line}" if line =~ /^ :/
      end.compact
      if fetch(:print_all, false)
        lines = "\nThe following settings are needed in your config (#{args.relative_path}).\n"
      else
        lines = "\nAdd the following setting(s) to your config (#{args.relative_path}) and try again:\n"
      end
      settings.each do |setting|
        if fetch(setting.split(',')[0].split(':')[1].to_sym).nil? or fetch(:print_all, false)
          lines += setting.chomp == setting ? "#{setting}\n" : setting
          need_moar_settings = true
        end
      end
      if need_moar_settings
        if fetch(:print_all, false)
          info lines
        else
          fatal lines if lines.lines.count > 2
          exit
        end
      end
    end
  end

end

def container_exists?(container_name)
  test "bash", "-c", "\"docker", "inspect", container_name, "&>", "/dev/null\""
end

def container_is_running?(container_name)
  test "[", "\"`docker", "inspect", "--format='{{.State.Running}}'",
    "#{container_name} 2>&1`\"", "=", "\"true\"", "]"
end

def container_is_restarting?(container_name)
  test "[", "\"`docker", "inspect", "--format='{{.State.Restarting}}'",
    container_name, "2>&1`\"", "=", "\"true\"", "]"
end

def localhost_port_responding?(port)
  test "nc", "127.0.0.1", port, "<", "/dev/null", ">", "/dev/null;",
    "[", "`echo", "$?`", "-eq", "0", "]"
end

def unix_user_exists?(user)
  test "bash", "-c", "\"id", user, "&>", "/dev/null\""
end

def unix_user_add(user)
  execute "adduser", "--disabled-password", "--gecos", "\"\"", user
end

def unix_user_get_id(user)
  capture("id", "-u", user).strip
end

def file_exists?(file)
  test "[", "-f", file, "]"
end

def directory_exists?(dir)
  test "[", "-d", dir, "]"
end

def check_stayed_running(name)
  sleep 3
  unless container_is_running?(name)
    fatal "Container #{name} on #{fetch(:domain)} did not stay running more than 3 seconds"
    exit
  end
  if container_is_restarting?(name)
    fatal "Container #{name} on #{fetch(:domain)} is stuck restarting itself."
    exit
  end
end

def create_container(name, command)
  warn "Starting a new container named #{name} on #{fetch(:domain)}"
  execute("docker", "run", command)
  check_stayed_running(name)
end

def start_container(name)
  warn "Starting an existing but non-running container named #{name}"
  execute("docker", "start", name)
  check_stayed_running(name)
end

def restart_container(name)
  warn "Restarting a running container named #{name}"
  execute("docker", "restart", name)
  check_stayed_running(name)
end
