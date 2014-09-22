class CompositeDevice extends Dmx.Device
  constructor: (devices) ->
    @devices = devices

  addDevice: (device) ->
    @devices.push(device)

  getDmxValues: () ->
    values = []
    for i in @devices
      values.push i.getDmxValues()...
    values

  setValue: (name, value) ->
    for i in @devices
      i.setValue name, value

class LoungeLight extends CompositeDevice
  constructor: (options) ->
    super(LoungeLight.generateDevices(options))

  @generateDevices: ({prefix, offset, universe}) ->
    devices = []
    for i in [0..5]
      device = new Dmx.Device
        name: "#{prefix}-#{i}"
        address: "#{universe}.#{offset + (i*3)}"
      device.template = LoungeLight.getSingleLightTemplate()
      devices.push device
    devices

  @getSingleLightTemplate: ->
    if not LoungeLight.singleLightTemplate?
      LoungeLight.singleLightTemplate = new Dmx.DeviceTemplate {name: 'single-pixel'}
      redField = new Dmx.Field
        name: 'red'
        offset: 0
        length: 1

      blueField = new Dmx.Field
        name: 'blue'
        offset: 1
        length: 1

      greenField = new Dmx.Field
        name: 'green'
        offset: 2
        length: 1

      LoungeLight.singleLightTemplate.fields = {
        red: redField
        green: greenField
        blue: blueField
      }

    return LoungeLight.singleLightTemplate

init = () ->

  window.dmxClient = new Dmx.CommandClient(ros)

  window.loungeLight = new LoungeLight
    prefix: "living-room"
    offset: 138
    universe: 1

$ ->

  window.ros = new ROSLIB.Ros({url : 'ws://192.168.5.118:4000'})

  ros.on 'connection', () ->
    console.log('ros socket ready')

    Dmx.factory = new ROSUtils.MessageFactory ros
    Dmx.factory.getMessageDetails 'lighting_msgs/DmxCommand', (type) ->
      console.log "type: #{type} ready"
      Dmx.emitter.emit 'ready'
      init()

  $('#colorpicker').colorPicker {
    format: 'rgb'
    colorChange: (evt, ui) ->
      $('body').css({
        backgroundColor: ui.color
      })

      window.loungeLight.setValue 'red', ui.red
      window.loungeLight.setValue 'blue', ui.blue
      window.loungeLight.setValue 'green', ui.green

      command = new Dmx_Msgs.DmxCommand {
        name: 'change_color'
        action: Dmx_Msgs.DmxCommand.ACTIONS.Display
        loop: false
      }

      frame = new Dmx_Msgs.DmxFrame {durationMs: 5000}
      frame.values = window.loungeLight.getDmxValues()
      command.layers.push(frame)

      window.dmxClient.command = command
      window.dmxClient.send()
  }
