import {PubSub} from 'pubsub-js';

let state = {}

PubSub.subscribe("reports", (topic, payload) => {
  payload.aircraft.forEach(a => {
    let aircraft = state[a.address]
    let topic = aircraft ? 'ac.updated' : 'ac.created'
    state[a.address] = a
    PubSub.publish(topic, a)
  })
  // Remove aircraft that timed out
  for (var address in state) {
    if (!state.hasOwnProperty(address)) continue;
    if (!payload.aircraft.some(a => a.address === address)) {
      delete state[address]
      // Broadcast address of aircraft removed
      PubSub.publish("ac.removed", address)
    }
  }
})

