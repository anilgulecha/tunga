consts =
  # endpoint type
  TCP_FORWARD    : 1
  HTTPS_FORWARD  : 2

  # endpoint state
  UNINITIALIZED  : 1
  ACTIVE         : 2
  TERMINATED     : 3

  # allowed outgoing ports
  PORT_SHELLINABOX : 81
  PORT_SSH         : 22

  # event ids
  EVENT_HTTP_PROXY_SETUP    : 100
  EVENT_HTTP_PROXY_CLOSED   : 110

  EVENT_TCP_PROXY_SETUP     : 200
  EVENT_TCP_USER_CONNECT    : 201
  EVENT_TCP_USER_DISCONNECT : 202
  EVENT_TCP_PROXY_CLOSED    : 210

  EVENT_PROXY_ERROR         : 300

module.exports = consts