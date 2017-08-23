import {Socket} from "phoenix"

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
          .setStyle({fillColor: getAltitudeColor(msg.altitude)})
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
          .setStyle({fillColor: getAltitudeColor(msg.altitude)})
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

  function removeAircraftFromMap(address, track_hash, map) {
    let aircraft = track_hash[address]
    if (aircraft) {
      aircraft.polyline.removeFrom(map)
      aircraft.marker.removeFrom(map)
    }
  }

  function getAltitudeColor(altitude) {
    // Original source: https://github.com/flightaware/dump1090/blob/master/public_html/planeObject.js

    let h, s, l

    if (typeof altitude === 'undefined' || altitude === null) {
      return [0, 0, 0]
    }

    s = 85
    l = 50

    let hpoints = [{alt: 2000,  val: 20},   // orange
                   {alt: 10000, val: 140},  // light green
                   {alt: 40000, val: 300}]  // magenta

    h = hpoints[0].val

    for (let i = hpoints.length-1; i >= 0; --i) {
      if (altitude > hpoints[i].alt) {
        if (i == hpoints.length-1) {
          h = hpoints[i].val
        } else {
          h = hpoints[i].val + (hpoints[i+1].val - hpoints[i].val) * (altitude - hpoints[i].alt) / (hpoints[i+1].alt - hpoints[i].alt)
        }
        break
      }
    }

    if (h < 0) {
      h = (h % 360) + 360
    } else if (h >= 360) {
      h = h % 360
    }

    if (s < 5) {
      s = 5
    } else if (s > 95) {
      s = 95
    }

    if (l < 5) {
      l = 5
    } else if (l > 95) {
      l = 95
    }

    return hslToHex(h, s, l)
  }

  function hslToHex(h, s, l) {
    // Source: https://stackoverflow.com/questions/36721830/convert-hsl-to-rgb-and-hex
    h /= 360;
    s /= 100;
    l /= 100;
    let r, g, b;
    if (s === 0) {
      r = g = b = l; // achromatic
    } else {
      const hue2rgb = (p, q, t) => {
        if (t < 0) t += 1;
        if (t > 1) t -= 1;
        if (t < 1 / 6) return p + (q - p) * 6 * t;
        if (t < 1 / 2) return q;
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
        return p;
      };
      const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      const p = 2 * l - q;
      r = hue2rgb(p, q, h + 1 / 3);
      g = hue2rgb(p, q, h);
      b = hue2rgb(p, q, h - 1 / 3);
    }
    const toHex = x => {
      const hex = Math.round(x * 255).toString(16);
      return hex.length === 1 ? '0' + hex : hex;
    };
    return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
  }
}
