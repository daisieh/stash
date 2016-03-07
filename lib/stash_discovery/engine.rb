require 'blacklight'
require 'geoblacklight'

# For undocumented reasons, sass-rails won't load without an explicit require
require 'sass-rails'

module StashDiscovery
  class Engine < ::Rails::Engine
    # :nocov:
    initializer :append_migrations do |app|
      unless app.root.to_s.match root.to_s
        config.paths['db/migrate'].expanded.each do |expanded_path|
          app.config.paths['db/migrate'] << expanded_path
        end
      end
    end
    # :nocov:
  end
end