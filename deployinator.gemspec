Gem::Specification.new do |s|
  s.name        = 'deployinator'
  s.version     = '0.0.0'
  s.date        = '2014-09-11'
  s.summary     = "Deploy Applications"
  s.description = "An Opinionated Deployment gem"
  s.authors     = ["david amick"]
  s.email       = "davidamick@ctisolutionsinc.com"
  s.files       = [
    "lib/deployinator.rb",
    "lib/deployinator/deploy.rb",
    "lib/deployinator/config.rb",
    "lib/deployinator/deploy_example_application.rb",
    "lib/deployinator/production_example_application.rb",
    "lib/deployinator/staging_example_application.rb"
  ]
  s.add_runtime_dependency 'capistrano', '= 3.2.1'
  s.homepage    =
    'http://rubygems.org/gems/deployinator'
  s.license       = 'MIT'
end
