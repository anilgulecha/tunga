express       = require 'express'
util          = require "util"
consts        = require("#{__dirname}/../../config/consts")
db            = require("#{__dirname}/../../models")
fs            = require 'fs'
http          = require 'http'
httpProxy     = require 'http-proxy'
tcpProxy      = require 'tcp-proxy'
config        = require(__dirname + '/../../config/config.json')[process.env.NODE_ENV || "development"]

router = express.Router()

httpsProxies = {}
tcpProxies = {}

setupHttpsProxy = (id, inport, outip, outport) ->
  console.log "Creating HTTPS:HTTP proxy #{inport} -> #{outip}:#{outport}"
  server = httpProxy.createServer
    target:
      host: outip
      port: outport
    ssl:
      key: fs.readFileSync config.privateKey, 'utf8'
      cert: fs.readFileSync config.certificate, 'utf8'
  server.listen inport
  httpsProxies[id] = {}
  httpsProxies[id].server = server
  server.on "error", (err, req, res) ->
    closeHttpProxy(id)

closeHttpProxy: (id) ->
  if httpsProxies[id]
    httpsProxies[id].server._server.close()

setupTcpProxy = (id, inport, outip, outport) ->
  console.log "Creating TCP proxy #{inport} -> #{outip}:#{outport}"
  server = tcpProxy.createServer
    target:
      host: outip
      port: outport
  server.listen inport
  tcpProxies[id] ={}
  tcpProxies[id].server = server
  server.on "error", (err, req, res) ->
    server.close()
  setTimeout ->
    console.log "closing!"
    server.close()
  , 30000


router.get '/status', (req, res) ->
  res.status(200).send
    "status" : "ok"

router.get '/endpoints', (req, res) ->
  db.EndPoints.findAll(
      where:
        state: [consts.ACTIVE, consts.UNINITIALIZED]
  ).success (rows) ->
    res.status(200).json
      models: rows

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
          if r.forwardType == consts.HTTPS_FORWARD
            setupHttpsProxy r.id, r.incomingPort, r.outgoingIP, r.outgoingPort
          else
            setupTcpProxy r.id, r.incomingPort, r.outgoingIP, r.outgoingPort

          res.status(200).json
            model: r
        ).error( (r) ->
          res.status(400).json
            error: "Unable to create an endpoint"
            data: r
        )

router.get '/endpoints/:id', (req, res) ->
  db.EndPoints.find
    where:
      id: req.params.id
  .success (r) ->
    if r
      res.status(200).json
        model: r
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
      res.status(200).json
        model: r
    else
      res.status(400).json
        error: "Unable to find endpoint."

module.exports = router