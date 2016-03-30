namespace :deployinator do

  task :load_settings do
    SSHKit.config.output_verbosity = fetch(:log_level)
  end

  task :sshkit_umask => 'deployinator:load_settings' do
    SSHKit.config.umask = "0027"
  end

  task :settings, [:absolute_path, :relative_path] => 'deployinator:load_settings' do |t, args|
    run_locally do
      if fetch(:print_all)
        lines = "\nThe following settings are needed in your config (#{args.relative_path}).\n"
        lines += File.read(args.absolute_path)
        info lines
        break
      end

      need_moar_settings = false
      settings = File.read(args.absolute_path).split("\nset").collect do |line|
        "set#{line}" if line =~ /^ :/
      end.compact
      lines = "\nAdd the following setting(s) to your config (#{args.relative_path}) and try again:\n"
      settings.each do |setting|
        if fetch(setting.split(',')[0].split(':')[1].to_sym).nil?
          lines += setting.chomp == setting ? "#{setting}\n" : setting
          need_moar_settings = true
        end
      end
      fatal(lines) if(lines.lines.count > 2) if(need_moar_settings)
      exit if need_moar_settings
    end
  end

end


def deployment_user_setup(templates_path)
  require 'erb'
  name = fetch(:deployment_username)
  unix_user_add(name) unless unix_user_exists?(name)
  execute "usermod", "-a", "-G", "sudo,docker,#{fetch(:webserver_username)}", name
  execute "mkdir", "-p", "/home/#{name}/.ssh"
  template_path = File.expand_path("./#{templates_path}/deployment_authorized_keys.erb")
  generated_config_file = ERB.new(File.new(template_path).read).result(binding)
  # upload! does not yet honor "as" and similar scoping methods
  upload! StringIO.new(generated_config_file), "/tmp/authorized_keys"
  execute "mv", "-b", "/tmp/authorized_keys", "/home/#{name}/.ssh/authorized_keys"
  execute "chown", "-R", "#{name}:#{name}", "/home/#{name}"
  execute "chmod", "700", "/home/#{name}/.ssh"
  execute "chmod", "600", "/home/#{name}/.ssh/authorized_keys"
end

# TODO when replacing this method with the new one, make sure the releases dir itself gets permissioned, just not it's contents.
def setup_file_permissions

  ignore_options = fetch(:ignore_permissions_dirs).collect do |dir|
    ["-not", "-path", "\"#{dir}\"", "-not", "-path", "\"#{dir}/*\""]
  end
  ignore_options += ["-not", "-path", "\"#{fetch(:deploy_to)}/releases/*\""]
  chown_ignore_options = fetch(:webserver_owned_dirs).collect do |dir|
    ["-not", "-path", "\"#{dir}\"", "-not", "-path", "\"#{dir}/*\""]
  end

  # chown webserver owned
  fetch(:webserver_owned_dirs).each do |dir|
    if directory_exists?(dir)
      execute "find", dir, ignore_options,
        '\(', "-not", "-user", fetch(:webserver_username), "-or",
        "-not", "-group", fetch(:webserver_username), '\)',
        "-print0", "|", "xargs", "--no-run-if-empty", "--null",
        "chown", "#{fetch(:webserver_username)}:#{fetch(:webserver_username)}"
    else
      execute "mkdir", "-p", dir
      execute "chown", "#{fetch(:webserver_username)}:#{fetch(:webserver_username)}", dir
    end
  end

  # chown
  execute "find", fetch(:deploy_to), ignore_options, chown_ignore_options,
    '\(', "-not", "-user", fetch(:deployment_username), "-or",
    "-not", "-group", fetch(:webserver_username), '\)',
    "-print0", "|", "xargs", "--no-run-if-empty", "--null",
    "chown", "#{fetch(:deployment_username)}:#{fetch(:webserver_username)}"

  # chmod executable
  fetch(:webserver_executable_dirs).each do |dir|
    if directory_exists?(dir)
      execute "find", dir, "-type", "f",
        "-not", "-perm", "0750",
        "-print0", "|", "xargs", "--no-run-if-empty", "--null", "chmod", "0750"
    # else # don't do this mkdir because it gets run as root and doesn't chown parent dirs
    #   execute "mkdir", "-p", dir
    #   execute "chown", "#{fetch(:deployment_username)}:#{fetch(:webserver_username)}", dir
    end
    ignore_options += ["-not", "-path", "\"#{dir}\"", "-not", "-path", "\"#{dir}/*\""]
  end

  # chmod writable
  fetch(:webserver_writeable_dirs).each do |dir|
    if directory_exists?(dir)
      execute "find", "-L", dir, "-type", "d",
        "-not", "-perm", "2770",
        "-print0", "|", "xargs", "--no-run-if-empty", "--null", "chmod", "2770"
      execute "find", "-L", dir, "-type", "f",
        "-not", "-perm", "0660",
        "-print0", "|", "xargs", "--no-run-if-empty", "--null", "chmod", "0660"
    else
      execute "mkdir", "-p", dir
      execute "chown", "#{fetch(:deployment_username)}:#{fetch(:webserver_username)}", dir
      execute "chmod", "2770", dir
    end
    ignore_options += ["-not", "-path", "\"#{dir}\"", "-not", "-path", "\"#{dir}/*\""]
  end

  # chmod
  execute "find", fetch(:deploy_to), "-type", "d", ignore_options,
    "-not", "-perm", "2750",
    "-print0", "|", "xargs", "--no-run-if-empty", "--null", "chmod", "2750"
  execute "find", fetch(:deploy_to), "-type", "f", ignore_options,
    "-not", "-perm", "0640",
    "-print0", "|", "xargs", "--no-run-if-empty", "--null", "chmod", "0640"
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

def unix_user_get_uid(user)
  capture("id", "-u", user).strip
end

def unix_user_get_gid(user)
  capture("id", "-g", user).strip
end

def file_exists?(file)
  test "[", "-f", file, "]"
end

def directory_exists?(dir)
  test "[", "-d", dir, "]"
end

def files_in_directory?(dir)
  test("[", "\"$(ls", "-A", "#{dir})\"", "]")
end
