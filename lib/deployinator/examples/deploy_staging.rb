# Simple Role Syntax
# ==================
# Supports bulk-adding hosts to roles, the primary server in each group
# is considered to be the first unless any hosts have the primary
# property set.  Don't declare `role :all`, it's a meta role.

set  :domain,           "my-app-staging.example.com"
set  :deploy_username,  "deployer"
set  :user_host,        "#{fetch(:deploy_username)}@#{fetch(:domain)}"

role :app, fetch(:user_host)
role :web, fetch(:user_host)
role :db,  fetch(:user_host)

#role :app, %w{deploy@example.com}
#role :web, %w{deploy@example.com}
#role :db,  %w{deploy@example.com}

# Extended Server Syntax
# ======================
# This can be used to drop a more detailed server definition into the
# server list. The second argument is a, or duck-types, Hash and is
# used to set extended properties on the server.

#server 'example.com', user: 'deploy', roles: %w{web app}, my_property: :my_value


# Custom SSH Options
# ==================
# You may pass any option but keep in mind that net/ssh understands a
# limited set of options, consult[net/ssh documentation](http://net-ssh.github.io/net-ssh/classes/Net/SSH.html#method-c-start).
#
# Global options
# --------------
#  set :ssh_options, {
#    keys: %w(/home/rlisowski/.ssh/id_rsa),
#    forward_agent: false,
#    auth_methods: %w(password)
#  }
#
# And/or per server (overrides global)
# ------------------------------------
# server 'example.com',
#   user: 'user_name',
#   roles: %w{web app},
#   ssh_options: {
#     user: 'user_name', # overrides user setting above
#     keys: %w(/home/user_name/.ssh/id_rsa),
#     forward_agent: false,
#     auth_methods: %w(publickey password)
#     # password: 'please use keys'
#   }

# Always use the master branch in production:
unless -> { fetch(:stage) } == "production"
  ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call
end

# If you are using nginxinator and postgresinator, your settings would look similar to this:
set :nginx_container_name,      "my-app-staging.example.com-nginx-80-443"
set :external_socket_path,      "/my-app-staging.example.com-nginx-80-443-conf/run"
set :postgres_container_name,   "my-app-staging.example.com-postgres-5432-master"
set :postgres_port,             "5432"
set :ruby_image_name,           "snarlysodboxer/ruby:1.9.3-p547"
set :ruby_container_name,       "my-app-staging.example.com-ruby-bluepill"
set :ruby_container_max_mem_mb, "1024"

set :rails_env, 'production'                  # If the environment differs from the stage name
set :migration_role, 'app'            # Defaults to 'db'
#set :conditionally_migrate, true           # Defaults to false. If true, it's skip migration if files in db/migrate not modified
set :assets_roles, [:app]            # Defaults to [:web]
#set :assets_prefix, 'prepackaged-assets'   # Defaults to 'assets' this should match config.assets.prefix in your rails config/application.rb
