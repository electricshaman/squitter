import {PubSub} from 'pubsub-js'

var $ = require('jquery');
require('datatables.net')(window, $);
require('datatables.net-bs')(window, $);

let table = $('#aircraft-table').DataTable({
  paging: false,
  data: [],
  rowId: 'address',
  columns: [
    { data: 'address', title: 'Address'},
    { data: 'callsign', title: 'Callsign'},
    { data: 'altitude', title: 'Altitude', render: (data, type, row) => data.toLocaleString()},
    { data: 'velocity_kt', title: 'Speed'},
    { data: 'distance', title: 'Distance'},
    { data: 'heading', title: 'Heading', render: (data, type, row) => data + '&deg;'},
    { data: 'msgs', title: 'Msgs'},
    { data: 'age', title: 'Age'}
  ]
});

table.on('click', 'tr', ev => {
  if(ev.target.nodeName.toLowerCase() == "th") return;
  let tr = ev.target.parentNode
  let row = table.row(tr)
  let address = row.id()
  PubSub.publish('ac.selected', address)
})

const selectAircraft = address => {
  let row = table.row(`#${address}`)
  $(row.node()).toggleClass('info').siblings().removeClass('info')
}

PubSub.subscribe('ac.created', (topic, ac) =>
  table.row.add(ac).draw())

PubSub.subscribe('ac.updated', (topic, ac) =>
  table.row(`#${ac.address}`).data(ac).draw())

PubSub.subscribe('ac.removed', (topic, address) =>
  table.row(`#${address}`).remove().draw())

PubSub.subscribe('marker.selected', (topic, address) => {
  selectAircraft(address)
})

PubSub.subscribe('marker.unselected', (topic, address) => {
  $(table.rows().nodes()).removeClass('info')
})
