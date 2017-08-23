import {Socket} from "phoenix"
import {altitudeToColor} from "./altitude"

if (document.getElementById('liveMap')) {
  let socket = new Socket("/socket")

  const defMarkerFillOpacity = 0.7
  const selMarkerFillOpacity = 1.0

  let tracks = {}
  var liveMap = L.map('liveMap').setView([35.0000, -97.0000], 8)

  L.tileLayer('https://cartodb-basemaps-{s}.global.ssl.fastly.net/{style}/{z}/{x}/{y}.png', {
    style: 'light_all',
    maxZoom: 18,
    attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>, &copy; <a href="https://carto.com/attribution">CARTO</a>'
  }).addTo(liveMap)

  let channel = socket.channel('aircraft:messages', {})
  socket.connect()

  channel.join()
    .receive('ok', res => {
      console.log('Joined channel', res)
      channel.push("roger", {})
    })
    .receive('error', res => {
      console.log('Failed to join channel!', res)
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
    stroke: false,
    fill: true,
    fillColor: '#854aa7',
    fillOpacity: defMarkerFillOpacity,
    radius: 6
  }

  let ttipOptions = {
    permanent: true,
    offset: [15, 0],
    className: 'ac_label',
    opacity: 0.9,
    direction: 'right'
  }

  channel.on('state_report', payload => {
    payload.aircraft.forEach(msg => {
      let aircraft = tracks[msg.address]
      if (!aircraft) {
        // Add new aircraft
        let ttip = L.tooltip(ttipOptions, marker)

        let marker = L.circleMarker(msg.latlon, acMarkerOptions)
          .bindTooltip(ttip)
          .setTooltipContent(formatTooltipContent(msg))
          .setStyle({fillColor: altitudeToColor(msg.altitude)})
          .addTo(liveMap)

        marker.closeTooltip()

        marker.address = msg.address
        marker.selected = false
        marker.on('click', handleMarkerClick)
        marker.on('mouseover', handleMarkerMouseOver)
        marker.on('mouseout', handleMarkerMouseOut)

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
      } else {
        // Update existing aircraft
        aircraft.polyline.addLatLng(msg.latlon)
        aircraft.marker.setLatLng(msg.latlon)
          .setTooltipContent(formatTooltipContent(msg))
          .setStyle({fillColor: altitudeToColor(msg.altitude)})
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

  const handleMarkerMouseOver = ev => {
    let marker = ev.target
    marker.openTooltip()
    showTrack(marker)
  }

  const handleMarkerMouseOut = ev => {
    let marker = ev.target
    if (!marker.selected) {
      marker.closeTooltip()
      hideTrack(marker)
    }
  }

  const handleMarkerClick = ev => {
    let marker = ev.target

    marker.selected = !marker.selected

    if (marker.selected) {
      marker.openTooltip()
      showTrack(marker)
    } else {
      marker.closeTooltip()
      hideTrack(marker)
    }
  }

  const showTrack = marker => {
    let addr = marker.address
    let line = tracks[addr].polyline

    marker.setStyle({
      fillOpacity: selMarkerFillOpacity
    })

    line.setStyle({
      opacity: 0.7
    })
  }

  const hideTrack = marker => {
    let addr = marker.address
    let line = tracks[addr].polyline

    marker.setStyle({
      fillOpacity: defMarkerFillOpacity
    })

    line.setStyle({
      opacity: 0.0
    })
  }

  const formatTooltipContent = ac =>
    `<strong>${(ac.callsign != "" ? ac.callsign : "???????")}</strong><br />
     ${ac.altitude} ft<br />
     ${ac.velocity_kt} kts<br />
     ${ac.heading}&deg;`

  const removeAircraftFromMap = (address, track_hash, map) => {
    let aircraft = track_hash[address]
    if (aircraft) {
      aircraft.polyline.removeFrom(map)
      aircraft.marker.removeFrom(map)
    }
  }
}
