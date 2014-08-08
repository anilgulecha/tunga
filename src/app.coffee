# Load Libraries
express         = require 'express'
path            = require 'path'
favicon         = require 'static-favicon'
logger          = require 'morgan'
cookieParser    = require 'cookie-parser'
bodyParser      = require 'body-parser'
fs              = require 'fs'
https           = require 'https'
clc             = require 'cli-color'


routes          = require './routes/index'

console.log "env = #{process.env.NODE_ENV}"
mode = process.env.NODE_ENV || "development"

console.log "------------------\n\n\nStarting in mode:  #{mode}\n\n\n-------------------\n"

config = require(__dirname + '/../config/config.json')[mode]

app = express()

app.use favicon(__dirname + '/../public/tunnel.ico')
app.use logger('dev')
app.use bodyParser.json()
app.use bodyParser.urlencoded()
app.use cookieParser()
app.use express.static(path.join(__dirname, 'public'))
app.disable 'x-powered-by'

app.all "*" , (req, res, next) ->
  if req.headers['x-api-key'] != config.API_KEY
    res.send ""
  else
    next()

app.use '/', routes.router

if config.raygun
  console.log clc.green("Configuring raygun")
  raygun = require 'raygun'
  raygunClient = new raygun.Client().init
    apiKey: 'config.raygun'
  app.use raygunClient.expressHandler
  raygunClient.send new Error("Started!")
else
  console.log "\nNO ERROR TRACKING SETUP\n"

credentials =
  key: fs.readFileSync(config.privateKey, 'utf8')
  cert: fs.readFileSync(config.certificate, 'utf8')

httpsServer = https.createServer credentials, app

server = httpsServer.listen config.port, ->
  console.log "Application listening for requests on port #{config.port} "

# commented code -- use later to disable server restart on errors

# checkAndExit = (force = false)->
#   if force or !routes.openProxies()
#     process.exit(-1)

# firstErrorTime = null
# process.on 'uncaughtException', (err) ->
#   console.log "catching error #{err}"
#   if firstErrorTime == null
#     console.log "setting timer"
#     setInterval ->
#       checkAndExit()
#       console.log config.maxRestartWaitSeconds, (new Date() - firstErrorTime), config.maxRestartWaitSeconds * 1000
#       if config.maxRestartWaitSeconds and  ((new Date() - firstErrorTime) > config.maxRestartWaitSeconds * 1000)
#         console.log clc.red("Exiting forcefully.")
#         checkAndExit(true)
#     ,5000
#   firstErrorTime = new Date() if !firstErrorTime
#   if config.raygun
#     raygunClient.send(err)
#   checkAndExit()

routes.restoreState()