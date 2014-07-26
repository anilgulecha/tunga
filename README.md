[[WORK IN PROGRESS]]

Tuna is a ```nodejs``` based TCP and HTTP(S) port forwarder. It allows dynamically modifiable proxy rules, controlled via a RESTful API.
All state is saved in a local sqlite database.

Devs:

Install node, npm
npm install.

# to run migrations.
node_modules/.bin/sequelize -m

# to start server.
NODE_ENV=development ./start.sh

or
NODE_ENV=production ./start.sh
