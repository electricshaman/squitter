use Mix.Config

config :logger, :console,
  format: "$time $metadata[$level] $levelpad$message\n",
  metadata: []

config :squitter, :decoding,
  avr_host: "localhost",
  avr_port: 30002,
  dump1090_path: "dump1090"

config :squitter, :site,
  location: {35.4690, -97.5085}

# import_config "#{Mix.env}.exs"
