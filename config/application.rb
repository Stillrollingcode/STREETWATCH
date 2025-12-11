require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Streetwatch
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Streetwatch app-specific placeholders (swap env vars once providers are chosen).
    config.x.storage.preferred_service = ENV.fetch("STREETWATCH_STORAGE", "cloud_or_local_TBD")
    config.x.payments.provider = ENV.fetch("STREETWATCH_PAYMENTS_PROVIDER", "stripe_or_paypal_TBD")
    config.x.memberships.trial_days = ENV.fetch("STREETWATCH_TRIAL_DAYS", 365).to_i
    config.x.support.tipping_provider = ENV.fetch("STREETWATCH_TIPS", "venmo_or_alt_TBD")
  end
end
