express       = require 'express'
util          = require "util"
consts        = require("#{__dirname}/../../config/consts")
db            = require("#{__dirname}/../../models")
fs            = require 'fs'
http          = require 'http'
httpProxy     = require 'http-proxy'
tcpProxy      = require 'tcp-proxy'
clc           = require 'cli-color'
async         = require 'async'
_             = require 'lodash'
version       = require("#{__dirname}/../../package.json")["version"]

env           = process.env.NODE_ENV or "development"
_c            = require("#{__dirname}/../../config/config.json")
config        = _c[env]

router = express.Router()

httpsProxies = {}
tcpProxies = {}


# HELPER FUNCTIONS.
# Called on server start -- so any active connections can be started.
#

restoreState = ->
  console.log clc.blue("Restoring any old connections.")
  db.EndPoints.findAll
    where:
      state: consts.ACTIVE
  .success (rows) ->
    for row in rows
      setupProxy row

# checks if there are open proxies

openProxies = ->
  if  _.isEmpty(httpsProxies) and _.isEmpty(tcpProxies)
    return false
  else
    return true


#
# wrapper function -- inturn call specific proxy function.
#

setupProxy = (endPoint) ->
  if endPoint.forwardType == consts.HTTPS_FORWARD
    setupHttpsProxy endPoint
  else
    setupTcpProxy endPoint

closeProxy = (endPoint) ->
  if endPoint.forwardType == consts.HTTPS_FORWARD
    closeHttpProxy endPoint.id
  else
    closeTcpProxy endPoint.id


#
# Actual proxy setup functions follow
#
#

setupHttpsProxy = (endPoint) ->
  id = endPoint.id
  inport = endPoint.incomingPort
  outip = endPoint.outgoingIP
  outport = endPoint.outgoingPort

  endPoint.makeEvent consts.EVENT_HTTP_PROXY_SETUP

  console.log clc.blue("Creating HTTPS:HTTP proxy (id: #{id}) #{inport} -> #{outip}:#{outport}")
  server = httpProxy.createServer
    target:
      host: outip
      port: outport
    ssl:
      key: fs.readFileSync config.privateKey, 'utf8'
      cert: fs.readFileSync config.certificate, 'utf8'
  server.listen inport
  endPoint.state = consts.ACTIVE
  endPoint.save()
  httpsProxies[id] = {}
  httpsProxies[id].server = server
  server.on "error", (err, req, res) =>
    endPoint.makeEvent consts.EVENT_PROXY_ERROR, err
    closeHttpProxy(id)

closeHttpProxy = (epid) ->
  if httpsProxies[epid]
    console.log clc.blue("Stopping http proxy id #{epid}")
    httpsProxies[epid].server._server.close()
    db.EndPoints.find
      where:
        id: epid
    .success (r) ->
      r.makeEvent consts.EVENT_HTTP_PROXY_CLOSED
      r.state = consts.TERMINATED
      r.save()
    delete httpsProxies[epid]

setupTcpProxy = (endPoint) ->
  id = endPoint.id
  inport = endPoint.incomingPort
  outip = endPoint.outgoingIP
  outport = endPoint.outgoingPort
  endPoint.makeEvent consts.EVENT_TCP_PROXY_SETUP
  console.log clc.blue("Creating TCP proxy (id: #{id}) #{inport} -> #{outip}:#{outport}")
  server = tcpProxy.createServer
    target:
      host: outip
      port: outport

  tcpProxies[id] ={}
  tcpProxies[id].server = server
  tcpProxies[id].sockets = []

  server.on "error", (err, req, res) ->
    server.close()
    endPoint.makeEvent consts.EVENT_PROXY_ERROR

  server.on "connection", (socket) ->
    tcpProxies[id].sockets.push(socket)
    endPoint.makeEvent consts.EVENT_TCP_USER_CONNECT
    socket.on "close", ->
      if tcpProxies[id] and tcpProxies[id].sockets
        tcpProxies[id].sockets.splice(tcpProxies[id].sockets.indexOf(socket), 1)
      endPoint.makeEvent consts.EVENT_TCP_USER_DISCONNECT

  server.listen inport
  endPoint.state = consts.ACTIVE
  endPoint.save()

closeTcpProxy = (epid) ->
  if tcpProxies[epid]
    console.log clc.blue("Stopping tcp proxy id #{epid}")
    if tcpProxies[epid].server
      tcpProxies[epid].server.close()
    if tcpProxies[epid].sockets
      for sock in tcpProxies[epid].sockets
        sock.end()
        #sock.destroy()
    db.EndPoints.find
      where:
        id: epid
    .success (r) ->
      r.makeEvent consts.EVENT_TCP_PROXY_CLOSED
      r.state = consts.TERMINATED
      r.save()
    delete tcpProxies[epid]

#
# Route handlers
#

router.get '/status', (req, res) ->
  async.parallel [
    (c) ->
      db.EndPoints.count
        where:
          state: consts.ACTIVE
      .success (r) ->
        c(null,r)
      .error (e) ->
        c(e)
    ,
    (c) ->
      db.EndPoints.count
        where:
          state: consts.UNINITIALIZED
      .success (r) ->
        c(null,r)
      .error (e) ->
        c(e)
    ,
    (c) ->
      db.EndPoints.count
        where:
          state: consts.TERMINATED
      .success (r) ->
        c(null,r)
      .error (e) ->
        c(e)
    ,
    (c) ->
      db.Events.count()
      .success (r) ->
        c(null,r)
      .error (e) ->
        c(e)
    ,
    (c) ->
      fs.stat config.storage, (e,s) ->
        c(e, s)
  ], (err,r) ->
    res.status(200).json
      endpoints:
        active: r[0]
        uninitialized: r[1]
        terminated: r[2]
      version: version
      eventsCount: r[3]
      db_size: "#{(r[4].size / 1024)} kb"
      err: err

# a simple endpoint to throw errors.
router.get "/throwerror", (req, res) ->
  throw new Error ("api error")
  res.status(200).json
    message: "throwing error"

# get all endpoint
router.get '/endpoints', (req, res) ->
  if req.query.terminated and req.query.terminated == "true"
    allowedStates = [consts.ACTIVE, consts.UNINITIALIZED, consts.TERMINATED]
  else
    allowedStates = [consts.ACTIVE, consts.UNINITIALIZED]

  limt = req.query.limit || 10
  offst = req.query.offset || 0
  db.EndPoints.findAll
    where:
      state: allowedStates
    offset: offst
    limit: limt
  .success (rows) ->
    res.status(200).json
      models: rows

# create an endpoint
router.post '/endpoints', (req, res) ->
  if !req.body.outip or
      !req.body.outport or
      (parseInt(req.body.outport) not in [consts.PORT_SHELLINABOX, consts.PORT_SSH])
    res.status(400).json
      error: "Invalid input"
  else
    db.EndPoints.freePort (port) ->
      if port == null
        res.status(400).json
          error: "No free port"
      else
        db.EndPoints.create(
          state: consts.UNINITIALIZED
          forwardType: if parseInt(req.body.outport) == consts.PORT_SHELLINABOX then consts.HTTPS_FORWARD else consts.TCP_FORWARD
          outgoingIP: req.body.outip
          outgoingPort: req.body.outport
          incomingPort: port
        ).success((r) ->
          setupProxy r
          res.status(200).json
            model: r
        ).error( (r) ->
          res.status(400).json
            error: "Unable to create an endpoint"
            data: r
        )

# get an endpoint
router.get '/endpoints/:id', (req, res) ->
  db.EndPoints.find
    where:
      id: req.params.id
  .success (r) ->
    if r
      r.getEvents (ev)->
        atts = r.dataValues
        atts.events = ev
        res.status(200).json
          model: atts
    else
      res.status(400).json
        error: "Unable to find endpoint."
  .error (r) ->
    res.status(400).json
      error: "Unable to find endpoint."


router.put '/endpoints/:id', (req, res) ->
  if !req.body.action or req.body.action not in ["close"]
    res.status(400).json
      error: "Invalid input."

  db.EndPoints.find
    where:
      id: req.params.id
  .success (r) ->
    if r
      closeProxy r
      res.status(200).json
        message: "success"
    else
      res.status(400).json
        error: "Unable to find endpoint."
  .error (r) ->
    res.status(400).json
      error: "Unable to find endpoint"

module.exports.router = router
module.exports.restoreState = restoreState
module.exports.openProxies = openProxies