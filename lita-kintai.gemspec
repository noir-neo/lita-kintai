Gem::Specification.new do |spec|
  spec.name          = "lita-kintai"
  spec.version       = "0.2.0"
  spec.authors       = ["Shoma SATO"]
  spec.email         = ["noir.neo.04@gmail.com"]
  spec.description   = "A lita handler for summarize attendance emails. Fuckin' legacy attendance management method by email!"
  spec.summary       = "A lita handler for summarize attendance emails."
  spec.homepage      = ""
  spec.license       = "MIT"
  spec.metadata      = { "lita_plugin_type" => "handler" }

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "lita", ">= 4.7"
  spec.add_runtime_dependency "google-api-client"
  spec.add_runtime_dependency "rufus-scheduler"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "rspec", ">= 3.0.0"
end
