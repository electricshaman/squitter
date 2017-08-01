use Mix.Config

config :squitter, start_pubsub: true

config :logger, :console,
  format: "$time $metadata[$level] $levelpad$message\n",
  metadata: []

# import_config "#{Mix.env}.exs"
