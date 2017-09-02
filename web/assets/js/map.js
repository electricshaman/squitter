import chroma from 'chroma-js'
import L from 'leaflet'
import {PubSub} from 'pubsub-js'
import 'leaflet-easybutton';
import 'leaflet.heat';
import simplify from 'simplify-js'
require('leaflet-hotline')(L);

if (document.getElementById('live-map')) {
  const tracks = {}
  const altColorScaleMin = 1000
  const altColorScaleMax = 39000
  const altColorScaleStep = 5000
  const altColorBands = ['darkseagreen', 'navy', 'fuchsia']
  const altColorScale = chroma.scale(altColorBands).mode('lch').domain([altColorScaleMin, altColorScaleMax])
  const palette = {}

  for(let alt = altColorScaleMin; alt <= altColorScaleMax; alt += altColorScaleStep) {
    palette[alt/altColorScaleMax] = altColorScale(alt).hex()
  }

  const liveMap = L.map('live-map')
  L.tileLayer('https://cartodb-basemaps-{s}.global.ssl.fastly.net/{style}/{z}/{x}/{y}.png', {
    style: 'light_all',
    attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>, &copy; <a href="https://carto.com/attribution">CARTO</a>'
  }).addTo(liveMap)

  liveMap.setView(SITE_LOCATION, 10)

  // Range rings
  const createRangeRings = center =>
    [50, 100, 150, 200, 250].map(r => L.circle(center, {
      radius: r * 1852,
      fill: false,
      weight: 1.0,
      opacity: 0.7,
      dashArray: '5,5',
      interactive: false
    }))

  const rings = createRangeRings(SITE_LOCATION)
  const rangeRingGroup = L.featureGroup(rings).addTo(liveMap)
  rangeRingGroup.bringToBack()
  liveMap.fitBounds(rangeRingGroup.getBounds())

  const trackGroup = L.layerGroup()
  const trackOptions = {
    smoothFactor: 2.0,
    weight: 2.0,
    outlineWidth: 0,
    palette: palette,
    min: altColorScaleMin,
    max: altColorScaleMax,
  }

  const posChangeMarkerOptions = {
    radius: 3,
    stroke: false,
    fillOpacity: 0.3,
  }

  const togglePosChanges = L.easyButton({
    states: [{
      stateName: 'show-pos-changes',
      icon: 'glyphicon-option-horizontal',
      title: 'Show Position Changes',
      onClick: function(control) {
        showAllPosChanges()
        control.state('hide-pos-changes')
      }
    }, {
      icon: 'glyphicon-option-horizontal',
      stateName: 'hide-pos-changes',
      onClick: function(control) {
        hideAllPosChanges()
        control.state('show-pos-changes')
      },
      title: 'Hide Position Changes'
    }]
  }).addTo(liveMap)

  const toggleTracks = L.easyButton({
    states: [{
      stateName: 'show-all-tracks',
      icon: 'glyphicon-eye-open',
      title: 'Show All Tracks',
      onClick: function(control) {
        liveMap.addLayer(trackGroup);
        control.state('hide-all-tracks');
      }
    }, {
      icon: 'glyphicon-eye-close',
      stateName: 'hide-all-tracks',
      onClick: function(control) {
        liveMap.removeLayer(trackGroup);
        control.state('show-all-tracks');
      },
      title: 'Hide All Tracks'
    }]
  }).addTo(liveMap)

  const heat = L.heatLayer([], {
    radius: 20,
    blur: 10
  })

  const toggleHeat = L.easyButton({
    states: [{
      stateName: 'show-heatmap',
      icon: 'glyphicon-fire',
      title: 'Toggle Heatmap',
      onClick: function(control) {
        liveMap.addLayer(heat);
        control.state('hide-heatmap');
      }
    }, {
      icon: 'glyphicon-fire',
      stateName: 'hide-heatmap',
      onClick: function(control) {
        liveMap.removeLayer(heat);
        control.state('show-heatmap');
      },
      title: 'Toggle Heatmap'
    }]
  }).addTo(liveMap)

  const ttipOptions = {
    direction: 'right',
    offset: [10, 0],
    opacity: 0.9,
  }

  PubSub.subscribe('ac.created', (topic, ac) => {
    // Add new aircraft
    const ttip = L.tooltip(ttipOptions)

    const icon = L.divIcon({
      className: 'ac-icon',
      iconAnchor: [10, 20],
      html: '<div><span class="glyphicon glyphicon-plane"></span></div>'
    })

    const marker = L.marker(ac.latlon, {icon: icon})
    .bindTooltip(ttip)
    .setTooltipContent(formatTooltipContent(ac))
    .addTo(liveMap)

    rotateMarker(marker, ac.heading)
    setMarkerColor(marker, altColorScale(ac.altitude))

    marker.address = ac.address
    marker.selected = false

    marker.on('click', handleMarkerClick)
    marker.on('mouseover', handleMarkerMouseOver)
    marker.on('mouseout', handleMarkerMouseOut)

    const points = getInitialTrackPoints(ac)
    const posChangeGroup = L.layerGroup()

    points.forEach(p => {
      const [lat, lon, alt] = p
      const altColor = altColorScale(alt)
      posChangeGroup.addLayer(createPositionChangeMarker(p, altColor))
      heat.addLatLng([lat, lon, 1.0])
    })

    const track = L.hotline(points, trackOptions)
    trackGroup.addLayer(track)

    tracks[ac.address] = {
      track: track,
      marker: marker,
      posChanges: posChangeGroup
    }
  })

  PubSub.subscribe('ac.updated', (topic, ac) => {
    // Update existing aircraft
    const aircraft = tracks[ac.address]

    const prevPositions = aircraft.track.getLatLngs()
    const lastPos = prevPositions.length > 0 ? prevPositions[prevPositions.length - 1] : L.latLng(0, 0)

    const [lat, lon] = ac.latlon

    // Only add new position if it changes
    if (lat != lastPos.lat && lon != lastPos.lng) {
      const position = [lat, lon, ac.altitude]
      const altColor = altColorScale(ac.altitude)

      aircraft.track.addLatLng(position)
      heat.addLatLng([lat, lon, 1.0])
      aircraft.posChanges.addLayer(createPositionChangeMarker(position, altColor))

      rotateMarker(aircraft.marker, ac.heading)
      setMarkerColor(aircraft.marker, altColor)
      aircraft.marker.setLatLng(ac.latlon)
        .setTooltipContent(formatTooltipContent(ac))
    }
  })

  PubSub.subscribe('ac.removed', (topic, address) => {
    removeAircraftFromMap(address, tracks, liveMap, trackGroup)
    delete tracks[address]
  })

  PubSub.subscribe('ac.selected', (topic, address) => {
    const ac = tracks[address]
    if (ac) {
      toggleMarker(ac.marker)
    }
  })

  const createPositionChangeMarker = (point, color) => L.circleMarker(point, Object.assign(posChangeMarkerOptions, {fillColor: color}))

  const getInitialTrackPoints = aircraft => {
    if (aircraft.position_history) {
      // Thin out the historical points in case we have a ton
      // x = longitude, y = latitude
      const pointsToSimplify = aircraft.position_history.map(p => ({x: p[1], y: p[0], z: p[2]}))
      const simplifiedPoints = simplify(pointsToSimplify, 0.10)
      // Put the simplified points back into the format expected by Leaflet
      return simplifiedPoints.map(p => [p.y, p.x, p.z])
    } else {
      return [aircraft.latlon.concat([aircraft.altitude])]
    }
  }

  const handleMarkerMouseOver = ev => {
    const marker = ev.target
    showTrack(marker)
  }

  const handleMarkerMouseOut = ev => {
    const marker = ev.target
    if (!marker.selected) {
      hideTrack(marker)
    }
  }

  const handleMarkerClick = ev => {
    const marker = ev.target
    toggleMarker(marker)
  }

  const rotateMarker = (marker, angle) => {
    const element = marker.getElement()
    const iconSpan = element.firstElementChild.firstElementChild
    iconSpan.style.transform = `rotateZ(${angle}deg)`
  }

  const toggleMarker = marker => {
    hideAllTracks()
    if(!marker.selected) {
      marker.selected = true
      showTrack(marker)
      PubSub.publish('marker.selected', marker.address)
    } else {
      marker.selected = false
      PubSub.publish('marker.unselected', marker.address)
    }
  }

  const hideAllTracks = () => {
    for(let address of Object.keys(tracks)) {
      liveMap.removeLayer(tracks[address].track)
    }
  }

  const showAllPosChanges = () => {
    for(let address of Object.keys(tracks)) {
      liveMap.addLayer(tracks[address].posChanges)
    }
  }

  const hideAllPosChanges = () => {
    for(let address of Object.keys(tracks)) {
      liveMap.removeLayer(tracks[address].posChanges)
    }
  }

  const showTrack = marker => {
    const addr = marker.address
    const track = tracks[addr].track
    liveMap.addLayer(track)
  }

  const hideTrack = marker => {
    const addr = marker.address
    const track = tracks[addr].track
    liveMap.removeLayer(track)
  }

  const formatTooltipContent = ac =>
    `<strong>${(ac.callsign ? ac.callsign : "???????")}</strong><br />
     ${(ac.registration ? ac.registration + '<br />' : '')}
     ${ac.altitude.toLocaleString()} ft<br />
     ${ac.velocity_kt} kts<br />
     ${(ac.heading != null ? ac.heading + '&deg;' : '')}`

  const removeAircraftFromMap = (address, track_hash, map, track_group) => {
    const aircraft = track_hash[address]
    if (aircraft) {
      aircraft.track.removeFrom(map)
      aircraft.posChanges.clearLayers()
      aircraft.posChanges.removeFrom(map)
      track_group.removeLayer(aircraft.track)
      aircraft.marker.removeFrom(map)
    }
  }

  const setMarkerColor = (marker, color) => {
    const element = marker.getElement()
    element.style.color = color
    //marker.setStyle({fillColor: color})
  }
}
