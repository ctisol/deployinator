Gem::Specification.new do |s|
  s.name        = 'deployinator'
  s.version     = '0.0.1'
  s.date        = '2014-11-06'
  s.summary     = "Deploy Applications"
  s.description = "An Opinionated Deployment gem"
  s.authors     = ["david amick"]
  s.email       = "davidamick@ctisolutionsinc.com"
  s.files       = [
    "lib/deployinator.rb",
    "lib/deployinator/deploy.rb",
    "lib/deployinator/config.rb",
    "lib/deployinator/examples/Capfile",
    "lib/deployinator/examples/deploy.rb",
    "lib/deployinator/examples/deploy_staging.rb",
    "lib/deployinator/examples/Dockerfile",
    "lib/deployinator/examples/deployer_authorized_keys.erb",
    "lib/deployinator/examples/application_unicorn.rb.erb",
    "lib/deployinator/examples/application_bluepill.rb.erb"
  ]
  s.add_runtime_dependency 'capistrano', '= 3.2.1'
  s.homepage    =
    'https://github.com/snarlysodboxer/deployinator'
  s.license       = 'GNU'
end
