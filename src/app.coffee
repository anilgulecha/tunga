# Load Libraries
express         = require "express"
path            = require 'path'
favicon         = require 'static-favicon'
logger          = require 'morgan'
cookieParser    = require 'cookie-parser'
bodyParser      = require 'body-parser'
fs              = require 'fs'
https           = require 'https'

routes = require './routes/index'

config = require(__dirname + '/../config/config.json')[process.env.NODE_ENV || "development"]

app = express()

#app.set('views', path.join(__dirname, 'views'));
#app.set('view engine', 'jade');

#app.use favicon()
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

app.use '/', routes

credentials =
  key: fs.readFileSync(config.privateKey, 'utf8')
  cert: fs.readFileSync(config.certificate, 'utf8')

httpsServer = https.createServer credentials, app

server = httpsServer.listen config.port, ->
  console.log "Application listening for requests on port #{config.port} "
