use Mix.Config
target = Mix.Project.config[:target]

config :squitter_web, Squitter.Web.Endpoint,
  http: [
    port: 4001
  ],
  server: false
