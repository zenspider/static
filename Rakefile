# -*- ruby -*-

ENV.delete "MT_NO_ISOLATE" if ENV["MT_NO_ISOLATE"]

require "rubygems"
require "hoe"

Hoe.plugin :isolate
Hoe.plugin :seattlerb
Hoe.plugin :rdoc

Hoe.spec "static" do
  developer "Ryan Davis", "ryand-ruby@zenspider.com"

  dependency "ruby_parser",    "~> 3.0"
  dependency "sexp_processor", "~> 4.0"
  dependency "path_expander",  "~> 1.0"
  dependency "graph",          "~> 2.0"
  dependency "ruby2ruby",      "~> 2.0"

  license "MIT"
end

task :run => :isolate do
  dir = ENV["D"] || "~/Links/MD/app/models"

  ruby "-Ilib bin/static #{dir}"
end

# vim: syntax=ruby
