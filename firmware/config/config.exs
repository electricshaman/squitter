use Mix.Config

# Customize the firmware. Uncomment all or parts of the following
# to add files to the root filesystem or modify the firmware
# archive.

config :nerves, :firmware,
  rootfs_additions: "rootfs_additions"
#fwup_conf: "config/fwup.conf"

config :bootloader,
  init: [:nerves_runtime,
         :nerves_network,
         :nerves_init_net_kernel,
         :nerves_firmware_ssh],
  app: :squitter_firmware

config :nerves_firmware_ssh,
  authorized_keys: [File.read!(Path.expand("~/.ssh/id_rsa.pub"))]

network_ssid = System.get_env("SQUITTER_NETWORK_SSID") || Mix.shell.info "SQUITTER_NETWORK_SSID is unset"
network_psk = System.get_env("SQUITTER_NETWORK_PSK") || Mix.shell.info "SQUITTER_NETWORK_PSK is unset"
key_mgmt = System.get_env("SQUITTER_NETWORK_KEY_MGMT") || "WPA-PSK"

config :nerves_network, :default,
  wlan0: [ssid: network_ssid,
          psk: network_psk,
          key_mgmt: String.to_atom(key_mgmt)]

config :nerves_init_net_kernel,
  iface: "wlan0",
  name: "squitter"

config :squitter_web,
  namespace: Squitter.Web

# Configures the endpoint
config :squitter_web, Squitter.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "hurfAocg0W/AItXGaWvb4OFBrnopF5LdrakN8hLpgNiou63rSymOb9DPe+siVlzi",
  render_errors: [view: Squitter.Web.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Squitter.PubSub,
           adapter: Phoenix.PubSub.PG2]

config :squitter_web, Squitter.Web.Endpoint,
  http: [port: 4000],
  server: true,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [node: ["node_modules/brunch/bin/brunch", "watch", "--stdin",
                    cd: Path.expand("../../web/assets", __DIR__)]]

config :squitter,
  start_pubsub: false # Web will provide it

# import_config "#{Mix.Project.config[:target]}.exs"
