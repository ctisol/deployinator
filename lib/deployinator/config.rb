namespace :deployinator do

  desc 'Write example config files'
  task :write_example_configs do
    run_locally do
      execute "mkdir", "-p", "config/deploy", "templates/deploy"
      {
        "examples/Capfile"                        => "Capfile_example",
        "examples/config/deploy.rb"               => "config/deploy_example.rb",
        "examples/config/deploy/staging.rb"       => "config/deploy/staging_example.rb",
        "examples/Dockerfile"                     => "templates/deploy/Dockerfile_example",
        "examples/deployment_authorized_keys.erb" => "templates/deploy/deployment_authorized_keys_example.erb",
        "examples/unicorn.rb.erb"                 => "templates/deploy/unicorn_example.rb.erb",
        "examples/bluepill.rb.erb"                => "templates/deploy/bluepill_example.rb.erb"
      }.each do |source, destination|
        config = File.read(File.dirname(__FILE__) + "/#{source}")
        File.open("./#{destination}", 'w') { |f| f.write(config) }
        info "Wrote '#{destination}'"
      end
      info "Now remove the '_example' portion of their names or diff with existing files and add the needed lines."
    end
  end

end
