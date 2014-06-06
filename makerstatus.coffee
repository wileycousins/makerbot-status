module.exports = (MakerStatusModule = ->
  "use strict"
  events = require("events")
  q = require("q")
  serialport = require("serialport")
  util = require("./util")
  Serial = require("./serial")
  MakerStatus = ->

  MakerStatus::init = (portname, config) ->
    @port = new serialport.SerialPort(portname, config.serial, false)
    @timeout_ms = config.promise.timeout_ms
    @serial = new Serial(@port)
    return

  MakerStatus::reset = ->
    d = q.defer()
    if @port
      @port.close()
      @port.open ->
        d.resolve port
        return

    else
      d.reject
        name: "Reset Exception"
        message: "Port is not defined."

    d.promise

  MakerStatus::open = ->
    d = q.defer()
    @port.open ->
      d.resolve()
      return

    d.promise

  MakerStatus::close = ->
    @port.close()  if @port
    return

  MakerStatus::getBuildName = ->
    d = q.defer()
    packet = util.query(util.CONSTANTS.HOST.QUERY.GET_BUILD_NAME)
    unless @serial
      d.reject
        name: "Init Exception"
        message: "Serial not initialized"

    else
      @serial["write"](packet).then (res) ->
        if res[0] is util.CONSTANTS.RESPONSE_CODE.SUCCESS
          name = ""
          i = 1

          while i < res.byteLength
            name = name + String.fromCharCode(res[i])  unless res[i] is 0
            i++
          d.resolve buildname: name
        else
          d.reject res[0]
        return

    q.timeout d.promise, @timeout_ms, "Get Build Name Timeout Occured."

  MakerStatus::getToolheadTemperature = (tool) ->
    d = q.defer()
    tool = (if tool is null or tool is `undefined` then 0 else tool)
    packet = util.query(util.CONSTANTS.HOST.QUERY.TOOL_QUERY, tool, util.CONSTANTS.TOOL.QUERY.GET_TOOLHEAD_TEMP)
    unless @serial
      d.reject
        name: "Init Exception"
        message: "Serial not initialized"

    else
      @serial["write"](packet).done (res) ->
        if res[0] is util.CONSTANTS.RESPONSE_CODE.SUCCESS
          celsius = (res[1] | ((res[2] & 0xFF) << 8))
          d.resolve celsius: celsius
        else
          d.reject res[0]
        return

    q.timeout d.promise, @timeout_ms, "Get Toolhead Temperature Timeout Occured."

  MakerStatus::getBuildStatistics = ->
    d = q.defer()
    packet = util.query(util.CONSTANTS.HOST.QUERY.GET_BUILD_STATS)
    unless @serial
      d.reject
        name: "Init Exception"
        message: "Serial not initialized"

    else
      @serial["write"](packet).done (res) ->
        if res[0] is util.CONSTANTS.RESPONSE_CODE.SUCCESS
          stats =
            state: ""
            hours: 0
            minutes: 0

          build_state_consts = util.CONSTANTS.BUILD_STATE
          for state of build_state_consts
            if build_state_consts.hasOwnProperty(state)
              if build_state_consts[state] is res[1]
                stats.state = util.CONSTANTS.BUILD_STATE_DESC[state]
                break
          stats.hours = res[2]
          stats.minutes = res[3]
          d.resolve stats
        else
          d.reject res[0]
        return

    q.timeout d.promise, @timeout_ms, "Get Build Statistics Timeout Occured."

  MakerStatus
)()
