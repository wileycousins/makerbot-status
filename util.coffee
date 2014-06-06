module.exports = (UtilModule = ->
  "use strict"
  CONSTANTS =
    PROTOCOL_STARTBYTE: 0xD5
    MAX_PAYLOAD_LENGTH: 32
    HOST:
      QUERY:
        TOOL_QUERY: 10
        GET_BUILD_NAME: 20
        GET_BUILD_STATS: 24

    TOOL:
      QUERY:
        GET_TOOLHEAD_TEMP: 2
        GET_TOOLHEAD_TARGET_TEMP: 32

    RESPONSE_CODE:
      GENERIC_PACKET_ERROR: 0x80
      SUCCESS: 0x81
      ACTION_BUFFER_OVERFLOW: 0x82
      CRC_MISMATCH: 0x83
      COMMAND_NOT_SUPPORTED: 0x85
      DOWNSTREAM_TIMEOUT: 0x87
      TOOL_LOCK_TIMEOUT: 0x88
      CANCEL_BUILD: 0x89
      ACTIVE_LOCAL_BUILD: 0x8A
      OVERHEAT_STATE: 0x8B

    BUILD_STATE:
      NO_BUILD_INITIALIZED: 0x00
      BUILD_RUNNING: 0x01
      BUILD_FINISHED_NORMALLY: 0x02
      BUILD_PAUSED: 0x03
      BUILD_CANCELLED: 0x04
      BUILD_SLEEPING: 0x05

    BUILD_STATE_DESC:
      NO_BUILD_INITIALIZED: "Idle"
      BUILD_RUNNING: "Build Running"
      BUILD_FINISHED_NORMALLY: "Build Complete"
      BUILD_PAUSED: "Build Paused"
      BUILD_CANCELLED: "Build Cancelled"
      BUILD_SLEEPING: "No Build Active"

  
  ###
  CRC table from http://forum.sparkfun.com/viewtopic.php?p=51145
  ###
  _crctab = [
    0
    94
    188
    226
    97
    63
    221
    131
    194
    156
    126
    32
    163
    253
    31
    65
    157
    195
    33
    127
    252
    162
    64
    30
    95
    1
    227
    189
    62
    96
    130
    220
    35
    125
    159
    193
    66
    28
    254
    160
    225
    191
    93
    3
    128
    222
    60
    98
    190
    224
    2
    92
    223
    129
    99
    61
    124
    34
    192
    158
    29
    67
    161
    255
    70
    24
    250
    164
    39
    121
    155
    197
    132
    218
    56
    102
    229
    187
    89
    7
    219
    133
    103
    57
    186
    228
    6
    88
    25
    71
    165
    251
    120
    38
    196
    154
    101
    59
    217
    135
    4
    90
    184
    230
    167
    249
    27
    69
    198
    152
    122
    36
    248
    166
    68
    26
    153
    199
    37
    123
    58
    100
    134
    216
    91
    5
    231
    185
    140
    210
    48
    110
    237
    179
    81
    15
    78
    16
    242
    172
    47
    113
    147
    205
    17
    79
    173
    243
    112
    46
    204
    146
    211
    141
    111
    49
    178
    236
    14
    80
    175
    241
    19
    77
    206
    144
    114
    44
    109
    51
    209
    143
    12
    82
    176
    238
    50
    108
    142
    208
    83
    13
    239
    177
    240
    174
    76
    18
    145
    207
    45
    115
    202
    148
    118
    40
    171
    245
    23
    73
    8
    86
    180
    234
    105
    55
    213
    139
    87
    9
    235
    181
    54
    104
    138
    212
    149
    203
    41
    119
    244
    170
    72
    22
    233
    183
    85
    11
    136
    214
    52
    106
    43
    117
    151
    201
    74
    20
    246
    168
    116
    42
    200
    150
    21
    75
    169
    247
    182
    232
    10
    84
    215
    137
    107
    53
  ]
  _exception = ExceptionCreator = (name, message) ->
    name: name
    message: message

  
  ###
  Calculate 8-bit [iButton/Maxim CRC][http://www.maxim-ic.com/app-notes/index.mvp/id/27] of the payload
  @method CRC
  @param {ArrayBuffer} payload
  @return {uint8} Returns crc value on success, throws exceptions on failure
  ###
  CRC = CRC = (payload) ->
    unless payload
      throw _exception("Argument Exception", "payload is null or undefined")
    else throw _exception("Argument Exception", "payload is not an ArrayBuffer")  unless payload instanceof ArrayBuffer
    crc = 0
    i = 0

    while i < payload.byteLength
      crc = _crctab[crc ^ payload[i]]
      ++i
    crc

  
  ###
  Create protocol message from ArrayBuffer
  
  @method encode
  @param {ArrayBuffer} payload Single Payload of s3g Protocol Message
  @return {ArrayBuffer} Returns packet on success, throws exceptions on failure
  ###
  encode = Encode = (payload) ->
    unless payload
      throw _exception("Argument Exception", "payload is null or undefined")
    else unless payload instanceof ArrayBuffer
      throw _exception("Argument Exception", "payload is not an ArrayBuffer")
    else throw _exception("Packet Length Exception", "payload length (" + payload.byteLength + ") is greater than max (" + CONSTANTS.MAX_PAYLOAD_LENGTH + ").")  if payload.byteLength > CONSTANTS.MAX_PAYLOAD_LENGTH
    
    # Create Packet
    len = payload.byteLength
    packet = new DataView(new ArrayBuffer(len + 3)) # Protocol Bytes
    packet.setUint8 0, CONSTANTS.PROTOCOL_STARTBYTE
    packet.setUint8 1, len
    i = 0
    offset = 2

    while i < payload.byteLength
      packet.setUint8 offset, payload[i]
      ++i
      ++offset
    packet.setUint8 len + 2, CRC(payload)
    packet

  PacketStreamDecoder = ->
    @state = @STATES.WAIT_FOR_HEADER
    @payload = `undefined`
    @payloadOffset = 0
    @expectedLength = 0
    return

  
  ###
  Re-construct Packet one byte at a time
  @param _byte Byte to add to the stream
  ###
  PacketStreamDecoder::parseByte = (_byte) ->
    switch @state
      when @STATES.WAIT_FOR_HEADER
        throw _exception("Packet Header Exception", "packet header value incorrect(" + _byte + ")")  if _byte isnt CONSTANTS.PROTOCOL_STARTBYTE
        @state = @STATES.WAIT_FOR_LENGTH
      when @STATES.WAIT_FOR_LENGTH
        throw _exception("Packet Length Exception", "packet length (" + _byte + ") value greater than max.")  if _byte > CONSTANTS.MAX_PAYLOAD_LENGTH
        @expectedLength = _byte
        @state = @STATES.WAIT_FOR_DATA
      when @STATES.WAIT_FOR_DATA
        @payload = new ArrayBuffer(@expectedLength)  unless @payload
        @payload[@payloadOffset] = _byte
        ++@payloadOffset
        if @payloadOffset > @expectedLength
          throw _exception("Packet Length Exception", "packet length incorrect.")
        else @state = @STATES.WAIT_FOR_CRC  if @payloadOffset is @expectedLength
      when @STATES.WAIT_FOR_CRC
        crc = CRC(@payload)
        throw _exception("Packet CRC Exception", "packet crc incorrect.")  if crc isnt _byte
        @state = @STATES.PAYLOAD_READY
      else
        throw _exception("Parser Exception", "default state reached.")
    return

  PacketStreamDecoder::reset = ->
    @state = @STATES.WAIT_FOR_HEADER
    @payload = `undefined`
    @payloadOffset = 0
    @expectedLength = 0
    return

  PacketStreamDecoder::isPayloadReady = ->
    @state is @STATES.PAYLOAD_READY

  PacketStreamDecoder::STATES =
    WAIT_FOR_HEADER: 0
    WAIT_FOR_LENGTH: 1
    WAIT_FOR_DATA: 2
    WAIT_FOR_CRC: 3
    PAYLOAD_READY: 4

  query = BuildQuery = ->
    payload = new ArrayBuffer(arguments_.length)
    i = 0

    while i < arguments_.length
      payload[i] = arguments_[i]
      ++i
    packet = encode(payload)
    buffer = new Buffer(packet.byteLength, false)
    i = 0

    while i < packet.byteLength
      buffer[i] = packet[i]
      ++i
    buffer

  query: query
  CONSTANTS: CONSTANTS
  PacketStreamDecoder: PacketStreamDecoder
)()
