module.exports = (SerialModule = ->
  "use strict"
  events = require("events")
  q = require("q")
  util = require("./util")
  Serial = (port) ->
    @port = port
    @port.on "error", @err.bind(this)
    @port.on "data", @process.bind(this)
    @decoder = new util.PacketStreamDecoder()
    return

  Serial:: = Object.create(events.EventEmitter::)
  Serial::process = (buffer) ->
    try
      i = 0

      while i < buffer.length
        @decoder.parseByte buffer[i]
        if @decoder.isPayloadReady()
          payload = @decoder.payload
          @decoder.reset()
          @emit "payload", payload
        ++i
    catch err
      @decoder.reset()
      @emit "error", err
    return

  Serial::write = (buffer) ->
    d = q.defer()
    try
      @once "payload", (payload) ->
        d.resolve payload
        return

      @once "error", (err) ->
        d.reject err
        return

      @decoder.reset()
      unless Buffer.isBuffer(buffer)
        throw
          name: "Argument Exception"
          message: "buffer not of type Buffer"
      @port.write buffer, ((err) ->
        @emit "error", err  if err
        return
      ).bind(this)
    catch err
      @emit "error", err
    d.promise

  Serial::err = (err) ->
    @decoder.reset()
    @emit "error", err
    return

  Serial
)()
