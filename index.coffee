q = require("q")
serialport = require("serialport")
util = require("./util")
MakerStatus = require("./makerstatus")
config =
  promise:
    timeout_ms: 250

  serial:
    baudrate: 115200

makerbot = new MakerStatus()

# List Serial Ports
console.log 'scanning serial ports:'
serialport.list (err, ports) ->
  throw err  if err
  i = 0

  for port in ports
    console.log port
    if port.pnpId?.match("MakerBot") or port.manufacturer?.match("MakerBot Industries")
      console.log "Found MakerBot", port.comName
      makerbot.init port.comName, config
      makerbot.open().then(makerbot.getBuildName.bind(makerbot)).then((name) ->
        console.log "getBuildName:", name
        return
      ).then(makerbot.getBuildStatistics.bind(makerbot)).then((stats) ->
        console.log "getBuildStatistics:", stats
        return
      ).then(makerbot.getToolheadTemperature.bind(makerbot)).then((temp) ->
        console.log "getToolheadTemperature:", temp
        return
      ).fail((err) ->
        makerbot.close()
        console.log "Closing Serial Port."
        throw err
      ).done makerbot.close.bind(makerbot)
    ++i
  return

