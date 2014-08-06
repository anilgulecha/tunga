fs          = require "fs"
path        = require "path"
Sequelize   = require "sequelize"
_           = require "lodash"
consts      = require("#{__dirname}/../config/consts")

env         = process.env.NODE_ENV or "development"
_c          = require("#{__dirname}/../config/config.json")
config = _c[env]

sequelize = new Sequelize config.database, config.username, config.password, config

db = {}

# maximum number of events for an endpoint to record.
MAX_EVENTS = 30

EndPoints = sequelize.define "endpoints",
  id:
    type: Sequelize.INTEGER
    autoIncrement: true
    primaryKey: true
  createdAt: Sequelize.DATE
  updatedAt: Sequelize.DATE
  state: Sequelize.INTEGER
  forwardType: Sequelize.INTEGER
  incomingPort:
    type: Sequelize.INTEGER
    min: 2001
    max: 3001
  outgoingIP:
    type: Sequelize.STRING
    isIPv4: true
  outgoingPort:
    type: Sequelize.INTEGER
    isInt: true
,
  classMethods:
    freePort: (callback) ->
      @findAll(
        where:
          state: [consts.UNINITIALIZED, consts.ACTIVE]
        attributes:
          ['id','incomingPort']
      ).success( (rows)->
        inuse_ports = _.map rows, (r) ->
          r.dataValues.incomingPort
        callback _.first(_.difference([2001..3000], inuse_ports))
      ).error( ->
        callback null
      )

  instanceMethods:
    makeEvent: (evid) ->
      Events.makeEvent @id, evid

Events = sequelize.define "events",
  id:
    type: Sequelize.INTEGER
    autoIncrement: true
    primaryKey: true
  endpointId  : Sequelize.INTEGER
  eventId     : Sequelize.INTEGER
  timestamp   :
    type: Sequelize.DATE
    defaultValue: Sequelize.NOW
  message     :
    type: Sequelize.STRING
    defaultValue: ""
,
  timestamps: false
  hooks:
    beforeCreate: (evnt, callback) ->
      @count
        where:
          endpointId: evnt.endpointId
      .success (c) ->
        if c < MAX_EVENTS
          callback()
        else
          callback("max events reached for endpoint #{evnt.endpointId}")
  classMethods:
    makeEvent: (epid, evid) ->
      @create
        endpointId: epid
        eventId: evid
      .error (err) ->
        console.log " > Event error: #{err}"

db.EndPoints = EndPoints
db.Events    = Events

Object.keys(db).forEach (modelName) ->
  db[modelName].associate db  if "associate" of db[modelName]
  return

module.exports = _.extend(
  sequelize: sequelize
  Sequelize: Sequelize
, db)