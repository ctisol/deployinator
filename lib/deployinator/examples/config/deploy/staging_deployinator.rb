set :rails_env,                 'production'          # If the environment differs from the stage name
set :migration_role,            'app'                 # Defaults to 'db'
#set :conditionally_migrate,     true                  # Defaults to false. If true, it's skip migration if files in db/migrate not modified
set :assets_roles,              [:app]                # Defaults to [:web]
#set :assets_prefix,             'prepackaged-assets'  # Defaults to 'assets' this should match config.assets.prefix in your rails config/application.rb

# If you are using nginxinator and postgresinator, your settings would look similar to this:
  # if using nginxinator, :nginx_container_name will be set by it, so leave this one commented out:
#set :nginx_container_name,      "my-app-staging.example.com-nginx-80-443"
set :external_socket_path,      "/my-app-staging.example.com-nginx-80-443-conf/run"
set :internal_socket_path,      "/var/run/unicorn"
  # if using postgresinator, :postgres_container_name will be set by it, so leave this one commented out:
#set :postgres_container_name,   "my-app-staging.example.com-postgres-5432-master"
set :postgres_port,             "5432"
set :ruby_image_name,           "snarlysodboxer/ruby:1.9.3-p547"
set :ruby_container_name,       "my-app-staging.example.com-ruby-bluepill"
set :ruby_container_max_mem_mb, "1024"
set :bundler_version,           "1.7.4"
#set :use_cadvisor,              true                  # this is default
