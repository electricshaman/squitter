# Squitter
WIP
## Barebones Instructions for Raspberry Pi 3 (as of 8/31/2017)

These steps are a bit convoluted at the moment but I plan to add scripts to automate it soon.

Assuming Nerves and Phoenix (and npm and brunch) are installed:

1. `git clone https://github.com/electricshaman/squitter.git` (takes a little bit)
2. `cd squitter/web`
3. `mix deps.get`
4. `cd assets`
5. `npm install`
6. `brunch build --production`
7. `cd ../../firmware`
8. Edit environment variables in `env.sh` for appropriate network and site information
9. `source env.sh`
10. `mix deps.get`
11. `mix firmware && mix firmware.burn`
