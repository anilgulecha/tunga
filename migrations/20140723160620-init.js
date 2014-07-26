module.exports = {
  up: function(migration, DataTypes, done) {
    migration.createTable('endpoints', {
      id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true
      },
      createdAt: {
        type: DataTypes.DATE
      },
      updatedAt: {
        type: DataTypes.DATE
      },
      state: {
        type: DataTypes.INTEGER
      },
      forwardType: {
        type: DataTypes.INTEGER
      },
      incomingPort: {
        type: DataTypes.INTEGER
      },
      outgoingIP: {
        type: DataTypes.STRING
      },
      outgoingPort: {
        type: DataTypes.INTEGER
      }
    }).success( function() {
      migration.addIndex("endpoints", ['state'])
      migration.addIndex("endpoints", ['forwardType'])
      migration.addIndex("endpoints", ['createdAt'])
      migration.addIndex("endpoints", ['updatedAt'])
      migration.addIndex("endpoints", ['incomingPort'])
      migration.addIndex("endpoints", ['outgoingPort'])
      migration.addIndex("endpoints", ['outgoingIP'])
    });

    migration.createTable('events', {
      id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true
      },
      endpointId: {
        type: DataTypes.INTEGER
      },
      eventId: {
        type: DataTypes.INTEGER
      },
      timestamp: {
        type: DataTypes.DATE
      },
      message: {
        type: DataTypes.INTEGER
      }
    }).success( function() {
      migration.addIndex("events", ['endpointId'])
      migration.addIndex("events", ['eventId'])
    });

    return done();
  },
  down: function(migration, DataTypes, done) {
    return done();
  }
};
