set  :domain,                   "my-app-staging.example.com"
set  :user_host,                "#{fetch(:deployment_username)}@#{fetch(:domain)}"

role :app,                      fetch(:user_host)
role :web,                      fetch(:user_host)
role :db,                       fetch(:user_host)

set :rails_env,                 'production'
set :migration_role,            'app'                 # Defaults to 'db'
#set :conditionally_migrate,     true                  # Defaults to false. If true, it's skip migration if files in db/migrate not modified
set :assets_roles,              [:app]                # Defaults to [:web]
#set :assets_prefix,             'prepackaged-assets'  # Defaults to 'assets' this should match config.assets.prefix in your rails config/application.rb

set :webserver_container_name,  "my-app-staging.example.com-nginx-80-443"
set :postgres_container_name,   "my-app-staging.example.com-postgres-5432-master"
set :postgres_port,             "5432"
set :ruby_image_name,           "snarlysodboxer/ruby:1.9.3-p547"
set :ruby_container_name,       "#{fetch(:domain)}-ruby-bluepill"
set :ruby_container_max_mem_mb, "1024"
set :bundler_version,           "1.7.4"
set :use_cadvisor,              true
