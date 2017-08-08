use Mix.Config

config :logger, :console,
  format: "$time $metadata[$level] $levelpad$message\n",
  metadata: []

config :squitter, :site,
  location: {35.4690, -97.5085}

# import_config "#{Mix.env}.exs"
