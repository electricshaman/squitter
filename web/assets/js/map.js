import chroma from 'chroma-js'
import L from 'leaflet'
import {PubSub} from 'pubsub-js'
import 'leaflet-easybutton';

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

  const tracks = {}

  var liveMap = L.map('live-map')
  L.tileLayer('https://cartodb-basemaps-{s}.global.ssl.fastly.net/{style}/{z}/{x}/{y}.png', {
    style: 'light_all',
    attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>, &copy; <a href="https://carto.com/attribution">CARTO</a>'
  }).addTo(liveMap)

  liveMap.setView(SITE_LOCATION, 7)

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

  let rings = createRangeRings(SITE_LOCATION)
  let rangeRingGroup = L.featureGroup(rings).addTo(liveMap)
  rangeRingGroup.bringToBack()
  liveMap.fitBounds(rangeRingGroup.getBounds())

  let trackGroup = L.layerGroup();

  let trackOptions = {
    smoothFactor: 2.0,
    weight: 2.0,
    outlineWidth: 0,
    palette: palette,
    min: altColorScaleMin,
    max: altColorScaleMax,
  }

  let toggle = L.easyButton({
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
  });

  toggle.addTo(liveMap)

  // If using a circleMarker instead of an icon
  //let acMarkerOptions = {
  //  fillOpacity: 1.0,
  //  stroke: false,
  //  fillColor: '#854aa7',
  //  radius: 6,
  //  interactive: true
  //}

  let ttipOptions = {
    direction: 'right',
    offset: [10, 0],
    opacity: 0.9,
  }

  PubSub.subscribe('ac.created', (topic, ac) => {
    // Add new aircraft
    let ttip = L.tooltip(ttipOptions)

    let icon = L.divIcon({
      className: 'ac-icon',
      iconAnchor: [10, 20],
      html: '<div><span class="glyphicon glyphicon-plane"></span></div>'
    })

    let marker = L.marker(ac.latlon, {icon: icon})
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

    let points = [];
    if (ac.position_history) {
      ac.position_history.forEach(p => points.push(p))
    } else {
      let [lat, lon] = ac.latlon
      points.push([lat, lon, ac.altitude]);
    }

    let track = L.hotline(points, trackOptions)
    trackGroup.addLayer(track)

    tracks[ac.address] = {
      track: track,
      marker: marker
    }
  })

  PubSub.subscribe('ac.updated', (topic, ac) => {
    // Update existing aircraft
    var aircraft = tracks[ac.address]

    var [lat, lon] = ac.latlon
    let updatedTrack = aircraft.track.getLatLngs()
      .map(p => [p.lat, p.lng, p.alt])
      .concat([[lat, lon, ac.altitude]])

    aircraft.track.setLatLngs(updatedTrack)

    rotateMarker(aircraft.marker, ac.heading)
    setMarkerColor(aircraft.marker, altColorScale(ac.altitude))
    aircraft.marker.setLatLng(ac.latlon)
      .setTooltipContent(formatTooltipContent(ac))
  })

  PubSub.subscribe('ac.removed', (topic, address) => {
    removeAircraftFromMap(address, tracks, liveMap, trackGroup)
    delete tracks[address]
  })

  PubSub.subscribe('ac.selected', (topic, address) => {
    let ac = tracks[address]
    if (ac) {
      toggleMarker(ac.marker)
    }
  })

  const handleMarkerMouseOver = ev => {
    let marker = ev.target
    if (!marker.selected) {
      showTrack(marker)
    }
  }

  const handleMarkerMouseOut = ev => {
    let marker = ev.target
    if (!marker.selected) {
      hideTrack(marker)
    }
  }

  const handleMarkerClick = ev => {
    let marker = ev.target
    toggleMarker(marker)
  }

  const rotateMarker = (marker, angle) => {
    let element = marker.getElement()
    let iconSpan = element.firstElementChild.firstElementChild
    iconSpan.style.transform = `rotateZ(${angle}deg)`
  }

  const toggleMarker = marker => {
    hideAllTracks()
    if(!marker.selected) {
      PubSub.publish('marker.selected', marker.address)
      marker.selected = true
      showTrack(marker)
    } else {
      PubSub.publish('marker.unselected', marker.address)
      marker.selected = false
    }
  }

  const hideAllTracks = () => {
    for(let address of Object.keys(tracks)) {
      liveMap.removeLayer(tracks[address].track)
    }
  }

  const showTrack = marker => {
    let addr = marker.address
    let track = tracks[addr].track
    liveMap.addLayer(track)
  }

  const hideTrack = marker => {
    let addr = marker.address
    let track = tracks[addr].track
    liveMap.removeLayer(track)
  }

  const formatTooltipContent = ac =>
    `<strong>${(ac.callsign != "" ? ac.callsign : "???????")}</strong><br />
     ${ac.altitude.toLocaleString()} ft<br />
     ${ac.velocity_kt} kts<br />
     ${ac.heading}&deg;`

  const removeAircraftFromMap = (address, track_hash, map, track_group) => {
    let aircraft = track_hash[address]
    if (aircraft) {
      aircraft.track.removeFrom(map)
      track_group.removeLayer(aircraft.track)
      aircraft.marker.removeFrom(map)
    }
  }

  const setMarkerColor = (marker, color) => {
    let element = marker.getElement()
    element.style.color = color
    //marker.setStyle({fillColor: color})
  }
}
