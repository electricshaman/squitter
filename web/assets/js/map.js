if (document.getElementById('liveMap')) {
  var liveMap = L.map('liveMap').setView([35.0000, -97.0000], 8);
  L.tileLayer('http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: 'Fill this out!',
    maxZoom: 18,
  }).addTo(liveMap);
}
