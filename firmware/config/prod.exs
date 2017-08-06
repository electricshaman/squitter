use Mix.Config
target = Mix.Project.config[:target]

config :squitter_web, Squitter.Web.Endpoint,
  load_from_system_env: true,
  url: [
    host: "localhost",
    port: 80
  ],
  cache_static_manifest: "priv/static/cache_manifest.json"
