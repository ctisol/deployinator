module Capistrano
  module TaskEnhancements
    alias_method :deploy_original_default_tasks, :default_tasks
    def default_tasks
      deploy_original_default_tasks + [
        "deployinator:write_built_in",
        "deployinator:write_example_configs",
        "deployinator:write_example_configs:in_place"
      ]
    end
  end
end

namespace :deployinator do

  set :example, "_example"

  desc 'Write example config files'
  task :write_example_configs do
    run_locally do
      path = fetch(:deploy_templates_path, 'templates/deploy')
      execute "mkdir", "-p", "config/deploy", path
      {
        "examples/Capfile"                        => "Capfile#{fetch(:example)}",
        "examples/config/deploy.rb"               => "config/deploy#{fetch(:example)}.rb",
        "examples/config/deploy/staging.rb"       => "config/deploy/staging#{fetch(:example)}.rb",
        "examples/Dockerfile"                     => "#{path}/Dockerfile#{fetch(:example)}",
        "examples/deployment_authorized_keys.erb" =>
          "#{path}/deployment_authorized_keys#{fetch(:example)}.erb",
        "examples/unicorn.rb.erb"                 => "#{path}/unicorn#{fetch(:example)}.rb.erb",
        "examples/database.yml.erb"               => "#{path}/database#{fetch(:example)}.yml.erb",
        "examples/bluepill.rb.erb"                => "#{path}/bluepill#{fetch(:example)}.rb.erb",
      }.each do |source, destination|
        config = File.read(File.dirname(__FILE__) + "/#{source}")
        File.open("./#{destination}", 'w') { |f| f.write(config) }
        info "Wrote '#{destination}'"
      end
      unless fetch(:example).empty?
        info("Now remove the '#{fetch(:example)}' portion of their names " +
          "or diff with existing files and add the needed lines.")
      end
    end
  end

  desc 'Write example config files (will overwrite any existing config files).'
  namespace :write_example_configs do
    task :in_place do
      set :example, ""
      Rake::Task['deployinator:write_example_configs'].invoke
    end
  end

  desc 'Write a file showing the built-in overridable settings.'
  task :write_built_in do
    run_locally do
      {
        'built-in.rb'                         => 'built-in.rb',
      }.each do |source, destination|
        config = File.read(File.dirname(__FILE__) + "/#{source}")
        File.open("./#{destination}", 'w') { |f| f.write(config) }
        info "Wrote '#{destination}'"
      end
      info "Now examine the file and copy-paste into your deploy.rb or <stage>.rb and customize."
    end
  end

  # These are the only two tasks using :preexisting_ssh_user
  namespace :deployment_user do
    #desc "Setup or re-setup the deployment user, idempotently"
    task :setup do
      on roles(:all) do |h|
        on "#{fetch(:preexisting_ssh_user)}@#{h}" do |host|
          as :root do
            deployment_user_setup(fetch(:deploy_templates_path, 'templates/deploy'))
          end
        end
      end
    end
  end

  task :deployment_user do
    on roles(:all) do |h|
      on "#{fetch(:preexisting_ssh_user)}@#{h}" do |host|
        as :root do
          if unix_user_exists?(fetch(:deployment_username))
            info "User #{fetch(:deployment_username)} already exists. You can safely re-setup the user with 'deployinator:deployment_user:setup'."
          else
            Rake::Task['deployinator:deployment_user:setup'].invoke
          end
        end
      end
    end
  end

  task :webserver_user do
    on roles(:app) do
      as :root do
        unix_user_add(fetch(:webserver_username)) unless unix_user_exists?(fetch(:webserver_username))
      end
    end
  end

  task :file_permissions => [:deployment_user, :webserver_user] do
    on roles(:app) do
      as :root do
        setup_file_permissions
      end
    end
  end
  after   'deploy:check',   'deployinator:file_permissions'
  before  'deploy:restart', 'deployinator:file_permissions'

end
