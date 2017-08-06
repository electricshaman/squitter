use Mix.Config

config :logger, :console,
  format: "$time $metadata[$level] $levelpad$message\n",
  metadata: []

# import_config "#{Mix.env}.exs"
