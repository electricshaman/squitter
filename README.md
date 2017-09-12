# Squitter
WIP
## Barebones Instructions for Raspberry Pi 3 (as of 8/31/2017)

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
11. `mix deps.get`
12. `mix firmware && mix firmware.burn`
