# This file is used by Rack-based servers to start the application.

require_relative "config/environment"

run Rails.application
Rails.application.load_server

# TODO: mount future services here (health check, status page, or API-only rack apps)
