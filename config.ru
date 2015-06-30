require './lib/comixzap/environment'

ComixZap::Environment::setup!

require 'comixzap'

app = ComixZap::Server.new
run app
