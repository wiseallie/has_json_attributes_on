$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "has_json_attributes_on/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "has_json_attributes_on"
  s.version     = HasJsonAttributesOn::VERSION
  s.authors     = ["wiseallie"]
  s.email       = ["wiseallie@gmail.com"]
  s.homepage    = "https://github.com/wiseallie/has_json_attributes_on"
  s.summary     = "ActiveRecord: Gives the ability to store attributes in one JSON or JSONB column in the database and provides validations, typecasting and default values on the accessors"
  s.description = "Only supports Postgresql JSON & JSONB columns at the moment"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]

  s.add_dependency "rails", "~> 4.2.0"
  s.add_dependency "pg"
  s.add_dependency  "virtus", "~> 1.0.5"
  s.add_dependency  "default_value_for", "~> 3.0.1"
end
