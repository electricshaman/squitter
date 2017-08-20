import {Socket} from "phoenix"

if (document.getElementById('liveMap')) {
  let socket = new Socket("/socket")
  var liveMap = L.map('liveMap').setView([35.0000, -97.0000], 8)
  L.tileLayer('https://cartodb-basemaps-{s}.global.ssl.fastly.net/{style}/{z}/{x}/{y}.png', {
    style: "light_all",
    maxZoom: 18,
    attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>, &copy; <a href="https://carto.com/attribution">CARTO</a>'
  }).addTo(liveMap)

  let tracks = {}
  let channel = socket.channel("aircraft:messages", {})

  socket.connect()

  channel.join()
    .receive("ok", resp => {
      console.log("Joined successfully", resp)
    })
    .receive("error", resp => {
      console.log("Unable to join", resp)
    })

  let polyOptions = {
    color: 'red',
    weight: 2,
    opacity: 0.8
  }

  channel.on("state_vector", payload => {
    payload.messages.forEach(msg => {
      let aircraft = tracks[msg.address]
      if (!aircraft) {
        let poly = L.polyline([msg.latlon], polyOptions).addTo(liveMap);
        tracks[msg.address] = {
          polyline: poly
        }
      } else {
        let poly = aircraft.polyline
        poly.addLatLng(msg.latlon)
      }
    })
  })

  channel.on("timeout", payload => {
    payload.messages.forEach(msg => {
      removeAircraftFromMap(msg.address, tracks, liveMap)
    })
  })

  channel.on("terminated", payload => {
    payload.messages.forEach(msg => {
      removeAircraftFromMap(msg.address, tracks, liveMap)
    })
  })

  function removeAircraftFromMap(address, track_hash, map) {
    let aircraft = track_hash[address]
    if (aircraft) {
      let poly = aircraft.polyline
      poly.removeFrom(map)
    }
  }
}
