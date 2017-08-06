use Mix.Config
target = Mix.Project.config[:target]

config :squitter_web, Squitter.Web.Endpoint,
  http: [
    port: 4000
  ],
  server: true,
  debug_errors: true,
  check_origin: false,
  code_reloader: target == "host",
  watchers: (if target == "host" do
    [node: ["node_modules/brunch/bin/brunch", "watch", "--stdin",
                      cd: Path.expand("../../web/assets", __DIR__)]]
  else
    []
  end),
  live_reload: (if target == "host" do
    [
      patterns: [
        ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
        ~r{priv/gettext/.*(po)$},
        ~r{lib/squitter_web/views/.*(ex)$},
        ~r{lib/squitter_web/templates/.*(eex)$}
      ]
    ]
  else
    []
  end)
