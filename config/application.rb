require_relative 'boot'
require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Accounts
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    config.i18n.default_locale = :en
    config.i18n.available_locales = %w(en pl)
    config.i18n.fallbacks = [I18n.default_locale]

    # Use the ExceptionsController to rescue routing/bad request exceptions
    # https://coderwall.com/p/w3ghqq/rails-3-2-error-handling-with-exceptions_app
    config.exceptions_app = ->(env) { ExceptionsController.action(:rescue_from).call(env) }

    # Use delayed_job for background jobs
    config.active_job.queue_adapter = :delayed_job

    def is_real_production?
      secrets[:environment_name] == 'production'
    end

    # https://guides.rubyonrails.org/upgrading_ruby_on_rails.html#new-framework-defaults
    config.active_record.belongs_to_required_by_default = false
    config.autoload_paths += %W(#{config.root}/lib)

    # Use specific layouts for different DoorKeeper activities
    config.to_prepare do
      # Only Applications list
      Doorkeeper::ApplicationsController.layout "admin"
      # Only Authorization endpoint
      Doorkeeper::AuthorizationsController.layout "application"
      # Only Authorized Applications
      Doorkeeper::AuthorizedApplicationsController.layout "application"
      # Include ApplicationHelpers from this app to use with Doorkeeper
      # include only the ApplicationHelper module
      Doorkeeper::ApplicationController.helper ApplicationHelper
      # include all helpers from your application
      Doorkeeper::ApplicationController.helper Accounts::Application.helpers
    end
  end
end
