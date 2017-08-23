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
      channel.push("roger", {})
    })
    .receive("error", resp => {
      console.log("Unable to join", resp)
    })

  let polyOptions = {
    smoothFactor: 3.0,
    interactive: false,
    color: 'black',
    weight: 2,
    opacity: 0.0
  }

  let acIcon = L.icon({
    iconUrl: '/images/plane_icon.png',
    iconSize: [32, 38],
    iconAnchor: [0, 0],
    popupAnchor: [0, 0],
    shadowUrl: '/images/plane_icon_shadow.png',
    shadowSize: [32, 38],
    shadowAnchor: [0, 0]
  })

  let acMarkerOptions = {
    //icon: acIcon
    stroke: true,
    color: '#854aa7',
    weight: 2,
    opacity: 0.9,
    fill: true,
    fillColor: '#854aa7',
    fillOpacity: 1.0,
    radius: 4
  }

  channel.on("state_report", payload => {
    payload.aircraft.forEach(msg => {
      let aircraft = tracks[msg.address]
      if (!aircraft) {
        let marker = L.circleMarker(msg.latlon, acMarkerOptions)
          .addTo(liveMap)
          .bindPopup(msg.address + '<br />' + msg.callsign)

        marker.address = msg.address

        let poly = L.polyline([msg.latlon], polyOptions)

        if (msg.position_history) {
          msg.position_history.forEach(pos => {
            poly.addLatLng(pos)
          })
        }

        poly.addTo(liveMap)
        poly.bringToBack()

        tracks[msg.address] = {
          polyline: poly,
          marker: marker
        }

        marker.on('click', ev => {
          let a = ev.target.address
          let p = tracks[a].polyline
          let o = p.options.opacity > 0 ? 0 : 0.7
          p.setStyle({opacity: o})
          Object.keys(tracks).forEach(ta => {
            if(ta != a) {
              tracks[ta].polyline.setStyle({opacity: 0})
            }
          })
        })

      } else {
        aircraft.polyline.addLatLng(msg.latlon)
        aircraft.marker.setLatLng(msg.latlon)
      }
    })

    // Remove aircraft that are no longer part of the report
    for (var address in tracks) {
      if (!tracks.hasOwnProperty(address)) continue;
      if (!payload.aircraft.some(a => a.address === address)) {
        removeAircraftFromMap(address, tracks, liveMap)
        delete tracks[address]
      }
    }

  })

  function removeAircraftFromMap(address, track_hash, map) {
    let aircraft = track_hash[address]
    if (aircraft) {
      aircraft.polyline.removeFrom(map)
      aircraft.marker.removeFrom(map)
    }
  }
}
