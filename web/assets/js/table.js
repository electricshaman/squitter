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
    { data: 'altitude', title: 'Altitude',
      className: 'align-right',
      render: (data, type, row) => {
        let alt = data.toLocaleString()
        switch(row.vr_dir) {
          case 'up':
            return `${alt} <span class="altitude-symbol glyphicon glyphicon-triangle-top"></span>`
          case 'down':
            return `${alt} <span class="altitude-symbol glyphicon glyphicon-triangle-bottom"></span>`
          default:
            return `${alt} <div class="altitude-spacer"></div>`
        }
      }
    },
    { data: 'velocity_kt', title: 'Speed'},
    { data: 'distance', title: 'Distance', render: data => data.toFixed(1)},
    { data: 'heading', title: 'Heading', render: data => data !== null ? `${data}&deg;` : ''},
    { data: 'msgs', title: 'Msgs', render: data => data.toLocaleString()},
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
