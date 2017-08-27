import chroma from 'chroma-js'
import L from 'leaflet';
import socket from "./socket"

require('leaflet-hotline')(L);

if (document.getElementById('live-map')) {
  const altColorScaleMin = 1000
  const altColorScaleMax = 39000
  const altColorScaleStep = 5000
  const altColorBands = ['darkseagreen', 'navy', 'fuchsia']
  const altColorScale = chroma.scale(altColorBands).mode('lch').domain([altColorScaleMin, altColorScaleMax]);

  var palette = {};
  for(var alt = altColorScaleMin; alt <= altColorScaleMax; alt += altColorScaleStep) {
    palette[alt/altColorScaleMax] = altColorScale(alt).hex()
  }

  const defMarkerFillOpacity = 0.7
  const selMarkerFillOpacity = 1.0
  const tracks = {}

  var liveMap = L.map('live-map')
  L.tileLayer('https://cartodb-basemaps-{s}.global.ssl.fastly.net/{style}/{z}/{x}/{y}.png', {
    style: 'light_all',
    attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>, &copy; <a href="https://carto.com/attribution">CARTO</a>'
  }).addTo(liveMap)

  let channel = socket.channel('aircraft:messages', {})
  channel.join()
    .receive('ok', res => {
      liveMap.setView(res.site_location, 7)
      console.log('Joined channel', res)
      channel.push("roger", {})
    })
    .receive('error', res => {
      console.log('Failed to join channel!', res)
    })

  let trackOptions = {
    smoothFactor: 2.0,
    weight: 1.5,
    outlineWidth: 0,
    palette: palette,
    min: altColorScaleMin,
    max: altColorScaleMax,
  }

  let acMarkerOptions = {
    stroke: false,
    fill: true,
    fillColor: '#854aa7',
    fillOpacity: defMarkerFillOpacity,
    radius: 6,
    interactive: true
  }

  let ttipOptions = {
    direction: 'right',
    permanent: true,
    offset: [15, 0],
    opacity: 0.9,
  }

  channel.on('state_report', payload => {
    payload.aircraft.forEach(msg => {
      let aircraft = tracks[msg.address]
      if (!aircraft) {
        // Add new aircraft

        let ttip = L.tooltip(ttipOptions)
        let marker = L.circleMarker(msg.latlon, acMarkerOptions)
        .bindTooltip(ttip)
        .setTooltipContent(formatTooltipContent(msg))
        .addTo(liveMap)

        marker.closeTooltip()
        setMarkerColor(marker, altColorScale(msg.altitude))

        marker.address = msg.address
        marker.selected = false
        marker.on('click', handleMarkerClick)
        marker.on('mouseover', handleMarkerMouseOver)
        marker.on('mouseout', handleMarkerMouseOut)

        let points = [];
        if (msg.position_history) {
          msg.position_history.forEach(p => points.push(p))
        } else {
          let [lat, lon] = msg.latlon
          points.push([lat, lon, msg.altitude]);
        }

        let track = L.hotline(points, trackOptions)

        tracks[msg.address] = {
          track: track,
          marker: marker
        }
      } else {
        // Update existing aircraft
        var [lat, lon] = msg.latlon
        let updatedTrack = aircraft.track.getLatLngs().map(p => [p.lat, p.lng, p.alt]).concat([[lat, lon, msg.altitude]])
        aircraft.track.setLatLngs(updatedTrack)

        setMarkerColor(aircraft.marker, altColorScale(msg.altitude))
        aircraft.marker.setLatLng(msg.latlon)
          .setTooltipContent(formatTooltipContent(msg))
        aircraft.marker.bringToFront()
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
    let line = tracks[addr].track

    marker.setStyle({
      fillOpacity: selMarkerFillOpacity
    })

    liveMap.addLayer(line)
  }

  const hideTrack = marker => {
    let addr = marker.address
    let line = tracks[addr].track

    marker.setStyle({
      fillOpacity: defMarkerFillOpacity
    })

    liveMap.removeLayer(line)
  }

  const formatTooltipContent = ac =>
    `<strong>${(ac.callsign != "" ? ac.callsign : "???????")}</strong><br />
     ${ac.altitude} ft<br />
     ${ac.velocity_kt} kts<br />
     ${ac.heading}&deg;`

  const removeAircraftFromMap = (address, track_hash, map) => {
    let aircraft = track_hash[address]
    if (aircraft) {
      aircraft.track.removeFrom(map)
      aircraft.marker.removeFrom(map)
    }
  }

  const setMarkerColor = (marker, color) => {
    marker.setStyle({fillColor: color})
  }
}
