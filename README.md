# Squitter

Warning: This project is under active development and could break at any time!

## Instructions for Raspberry Pi 3 (as of 9/11/2017)

These steps are a bit convoluted at the moment but I plan to add scripts to automate it soon (PRs welcome).

Assuming Nerves and Phoenix (and npm and brunch) are installed:

1. `git clone https://github.com/electricshaman/squitter.git` (takes a little bit)
2. `cd squitter/web`
3. `mix deps.get`
4. `cd assets`
5. `npm install`
6. `brunch build --production`
7. `cd ../../firmware`
8. `export MIX_TARGET=rpi3`
9. `export SQUITTER_NETWORK_SSID="White Government Van"`
10. `export SQUITTER_NETWORK_PSK="nothingtoseehere"`
11. Edit site location in `config/config.exs` for your site location's GPS coordinates.  Also change this in `squitter/web/lib/squitter_web/views/aircraft_view.ex` (temporarily hard coded).
12. `mix deps.get`
13. `mix firmware && mix firmware.burn`

## Instructions for host mode with RTL-SDR and dump1090 on localhost

Assuming Nerves and Phoenix (and npm and brunch) are installed.  Nerves is still needed even if you are running squitter locally.

1. `git clone https://github.com/electricshaman/squitter.git` (takes a little bit)
2. `cd squitter/web`
3. `mix deps.get`
4. `cd assets`
5. `npm install`
6. `brunch build --production`
7. `cd ../../firmware`
8. Edit site location in `config/config.exs` for your site location's GPS coordinates.  Also change this in `squitter/web/lib/squitter_web/views/aircraft_view.ex` (temporarily hard coded).
9. If dump1090 is not available on your PATH, change the dump1090_path config to point to it.
10. `export MIX_TARGET=host` # Only needed if you previously set MIX_TARGET to rpi3
11. `mix deps.get`
12. `iex -S mix`

## Instructions for host mode with dump1090 exposed on a remote host

Assuming Nerves and Phoenix (and npm and brunch) are installed.  Nerves is still needed even if you are running squitter locally.

1. `git clone https://github.com/electricshaman/squitter.git` (takes a little bit)
2. `cd squitter/web`
3. `mix deps.get`
4. `cd assets`
5. `npm install`
6. `brunch build --production`
7. `cd ../../firmware`
8. Edit site location in `config/config.exs` for your site location's GPS coordinates.  Also change this in `squitter/web/lib/squitter_web/views/aircraft_view.ex` (temporarily hard coded).
9. Point `avr_host` to the host which has dump1090 running (it should be running on the remote host with the `--net` option so that it exposes raw frames over port 30002).
10. `export MIX_TARGET=host` # Only needed if you previously set MIX_TARGET to rpi3
11. `mix deps.get`
12. `iex -S mix`

## License

Copyright (C) 2017-2020 Jeff Smith

Squitter source code is licensed under the [MIT License](https://github.com/electricshaman/squitter/blob/master/LICENSE).
