namespace :deployinator do

#  desc 'Ensure all deployinator specific settings are set, and warn and raise if not.'
#  task :check_settings do
#    run_locally do
#      deploy_rb         = File.expand_path("./config/deploy.rb")
#      deploy_dir        = File.expand_path("./config/deploy")
#      {
#        "Do not \"set :bundle_binstubs, ....\", deployinator will overwrite it and you'll be confused." =>
#          system("grep -R -q -E '^set\ :bundle_binstubs' #{deploy_rb} #{deploy_dir}"),
#        "Do not \"set :bundle_gemfile, ....\", deployinator will overwrite it and you'll be confused." =>
#          system("grep -R -q -E '^set\ :bundle_gemfile' #{deploy_rb} #{deploy_dir}"),
#        "You need \"set :domain, 'your.domain.com'\" in your config/deploy/#{fetch(:stage)}.rb file." =>
#          fetch(:domain).nil?,
#        "You need \"set :nginx_container_name, 'your_nginx_container_name'\" in your config/deploy/#{fetch(:stage)}.rb file." =>
#          fetch(:nginx_container_name).nil?,
#        "You need \"set :external_socket_path, 'your_external_socket_path'\" in your config/deploy/#{fetch(:stage)}.rb file." =>
#          fetch(:external_socket_path).nil?,
#        "You need \"set :postgres_container_name, 'your_postgres_container_name'\" in your config/deploy/#{fetch(:stage)}.rb file." =>
#          fetch(:postgres_container_name).nil?,
#        "You need \"set :postgres_port, 'your_postgres_port_number'\" in your config/deploy/#{fetch(:stage)}.rb file." =>
#          fetch(:postgres_port).nil?,
#        "You need \"set :ruby_image_name, 'your_ruby_image_name'\" in your config/deploy/#{fetch(:stage)}.rb file." =>
#          fetch(:ruby_image_name).nil?,
#        "You need \"set :ruby_container_name, 'your_ruby_container_name'\" in your config/deploy/#{fetch(:stage)}.rb file." =>
#          fetch(:ruby_container_name).nil?,
#        "You need \"set :ruby_container_max_mem_mb, 'your_ruby_container_max_mem_mb'\" in your config/deploy/#{fetch(:stage)}.rb file." =>
#          fetch(:ruby_container_max_mem_mb).nil?
#      }.each do |message, true_false|
#        fatal(message) and raise if true_false
#      end
#    end
#  end
#  before 'deploy:starting', 'deployinator:check_settings'

  # TODO make this better
  task :check_templates do
    run_locally do
      keys_template     = File.expand_path("./templates/deploy/deployer_authorized_keys.erb")
      bluepill_template = File.expand_path("./templates/deploy/#{fetch(:application)}_bluepill.rb.erb")
      unicorn_template  = File.expand_path("./templates/deploy/#{fetch(:application)}_unicorn.rb.erb")
      {
        "You need a templates/deploy/deployer_authorized_keys.erb file."            => keys_template,
        "You need a templates/deploy/#{fetch(:application)}_bluepill.rb.erb file."  => bluepill_template,
        "You need a templates/deploy/#{fetch(:application)}_unicorn.rb.erb file."   => unicorn_template,
      }.each do |message, file|
        fatal(message) and raise unless File.exists? file
      end
    end
  end
  before 'deploy:starting', 'deployinator:check_templates'

  desc 'Write example config files'
  task :write_example_configs do
    run_locally do
      execute "mkdir", "-p", "config/deploy", "templates/deploy"
      {
        "examples/Capfile"                                => "Capfile_example",
        "examples/config/deploy.rb"                       => "config/deploy_example.rb",
        "examples/config/deploy_deployinator.rb"          => "config/deploy_deployinator_example.rb",
        "examples/config/deploy/staging.rb"               => "config/deploy/staging_example.rb",
        "examples/config/deploy/staging_deployinator.rb"  => "config/deploy/staging_deployinator_example.rb",
        "examples/Dockerfile"                             => "templates/deploy/Dockerfile_example",
        "examples/deployer_authorized_keys.erb"           => "templates/deploy/deployer_authorized_keys_example.erb",
        "examples/application_unicorn.rb.erb"             => "templates/deploy/#{fetch(:application, "my_app")}_unicorn_example.rb.erb",
        "examples/application_bluepill.rb.erb"            => "templates/deploy/#{fetch(:application, "my_app")}_bluepill_example.rb.erb"
      }.each do |source, destination|
        config = File.read(File.dirname(__FILE__) + "/#{source}")
        File.open("./#{destination}", 'w') { |f| f.write(config) }
        info "Wrote '#{destination}'"
      end
      info "Now remove the '_example' portion of their names or diff with existing files and add the needed lines."
    end
  end
end
