Gem::Specification.new do |s|
  s.name        = 'deployinator'
  s.version     = '0.1.3'
  s.date        = '2015-01-17'
  s.summary     = "Deploy Applications"
  s.description = "Deploy Ruby on Rails using Capistrano and Docker"
  s.authors     = ["david amick"]
  s.email       = "davidamick@ctisolutionsinc.com"
  s.files       = [
    "lib/deployinator.rb",
    "lib/deployinator/deploy.rb",
    "lib/deployinator/check.rb",
    "lib/deployinator/config.rb",
    "lib/deployinator/helpers.rb",
    "lib/deployinator/built-in.rb",
    "lib/deployinator/examples/Capfile",
    "lib/deployinator/examples/config/deploy.rb",
    "lib/deployinator/examples/config/deploy/staging.rb",
    "lib/deployinator/examples/Dockerfile",
    "lib/deployinator/examples/deployment_authorized_keys.erb",
    "lib/deployinator/examples/unicorn.rb.erb",
    "lib/deployinator/examples/bluepill.rb.erb"
  ]
  s.required_ruby_version   =               '>= 1.9.3'
  s.requirements            <<              "Docker ~> 1.3.1"
  s.add_runtime_dependency  'capistrano',   '~> 3.2.1'
  s.add_runtime_dependency  'rake',         '~> 10.3.2'
  s.add_runtime_dependency  'sshkit',       '~> 1.5.1'
  s.homepage      =
    'https://github.com/snarlysodboxer/deployinator'
  s.license       = 'GNU'
end
