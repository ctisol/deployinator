namespace :config do
  set :stage, :staging
  desc 'Write deploy_example.rb and <stage>_example.rb files'
  task :write_examples do
    run_locally do
      execute "mkdir -p ./config/deploy"

      # example deploy.rb
      config = "set :application, 'example-app'"
      File.open('./config/deploy_example.rb', 'w') { |f| f.write(config) }

      # example <stage>.rb
      config = "set :example_attr, true"
      File.open('./config/deploy/stage_example.rb', 'w') { |f| f.write(config) }
    end
  end
end
