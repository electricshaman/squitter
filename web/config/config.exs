# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :squitter_web, namespace: Squitter.Web

# Configures the endpoint
config :squitter_web, Squitter.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "hurfAocg0W/AItXGaWvb4OFBrnopF5LdrakN8hLpgNiou63rSymOb9DPe+siVlzi",
  render_errors: [view: Squitter.Web.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Squitter.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console, metadata: [:request_id]

config :squitter_web, :generators, context_app: false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
