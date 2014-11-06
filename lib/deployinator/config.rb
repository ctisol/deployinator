namespace :config do
  set :stage, :staging
  desc 'Write deploy_example.rb and <stage>_example.rb files'
  task :write_examples do
    run_locally do
      execute "mkdir -p ./config/deploy"

      # example deploy.rb
      config = File.read(File.dirname(__FILE__) + '/deploy_example.rb')
      File.open('./config/deploy_example_application.rb', 'w') { |f| f.write(config) }

      # example production.rb
      config = File.read(File.dirname(__FILE__) + '/production_example.rb')
      File.open('./config/deploy/production_example_application.rb', 'w') { |f| f.write(config) }

      # example staging.rb
      config = File.read(File.dirname(__FILE__) + '/staging_example.rb')
      File.open('./config/deploy/staging_example_application.rb', 'w') { |f| f.write(config) }
    end
  end
end
