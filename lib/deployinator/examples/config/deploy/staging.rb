##### deployinator
### ------------------------------------------------------------------
set  :domain,                         "my-app-staging.example.com"
server fetch(:domain),
  :user                               => fetch(:deployment_username),
  :roles                              => ["app", "web", "db"]
set :rails_env,                       'production'
set :ruby_image_name,                 "snarlysodboxer/ruby:1.9.3-p547"
set :ruby_container_name,             "#{fetch(:domain)}-ruby-bluepill"
set :ruby_container_max_mem_mb,       "1024"
set :postgres_port,                   "5432"
### deployinator jobs
set :use_jobs,                        false
set :ruby_jobs_container_name,        "#{fetch(:domain)}-ruby-bluepill_jobs"
set :ruby_jobs_container_max_mem_mb,  "512"
### ------------------------------------------------------------------
