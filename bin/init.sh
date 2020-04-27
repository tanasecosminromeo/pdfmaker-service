#!/usr/bin/env bash
echo "Setting default env file"
cp .env.dist .env

if [[ ! -d var/logs/nginx ]]; then
   mkdir -m 0777 -p var/logs/nginx
fi

echo "Populate with current user (Note: The container will only be started by this user! This will prevent file errors)"
HOST_GID=$(./bin/readenv.sh HOST_GID)
HOST_UID=$(./bin/readenv.sh HOST_UID)

if [[ -z "$HOST_UID" ]]; then
    echo "HOST_UID=$(id -u)" >> .env
fi;

if [[ -z "$HOST_GID" ]]; then
    echo "HOST_GID=$(id -g)" >> .env
fi;


WEB_PORT=8111
APP_TOKEN=ChangeMePlease

read -p "Please specify the HTTP port the app will be running at [8111]: " port
port=${port:-8111}
echo "WEB_PORT=$port" >> .env

read -p "Please specify the token you will use to send requests to your app [ChangeMePlease]: " token
token=${token:-"ChangeMePlease"}
echo "APP_TOKEN=$token" >> .env
