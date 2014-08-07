[[WORK IN PROGRESS]]

Tuna is a ```nodejs``` based TCP and HTTP(S) port forwarder. It allows dynamically modifiable proxy rules, controlled via a RESTful API.
All state is saved in a local sqlite database.

Devs:

# First run
Install node, npm
npm install.

# now create a config file as needed.
cp config/config.json.sample config/config.json

#  to run migrations.
node_modules/.bin/sequelize -m


# Regular runs
# to start server.
NODE_ENV=development ./start.sh

or

NODE_ENV=production ./start.sh

When developing you can create and destroy endpoints with:
 curl -k -X POST -H "X-API-KEY: abc" -d "outip=127.0.0.1" -d "outport=22" https://127.0.0.1:8443/endpoints

 curl -k -X PUT -H "X-API-KEY: abc" -d "action=close"  https://127.0.0.1:8443/endpoints/<id>

Parallely run the following in a terminal to keep track of open ports/connections.
 while true; do clear;date;pid=`ps -Ao "%p,%a" | grep "node bootstrap" | grep -v grep | cut -d"," -f1`; lsof -i -n | grep $pid;sleep 2;done
 
