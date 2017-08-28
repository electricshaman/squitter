import {Socket} from "phoenix"
import {PubSub} from "pubsub-js"

let socket = new Socket("/socket")
socket.connect()

let channel = socket.channel('aircraft:messages', {})
channel.join()
  .receive('ok', res => {
    console.log('Joined channel', res)
    channel.push("roger", {})
  })
  .receive('error', res => {
    console.log('Failed to join channel!', res)
  })

channel.on('state_report', payload => PubSub.publish('reports', payload))

export default socket
