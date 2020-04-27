#!/usr/bin/env bash
folder=${PWD##*/}
DOCKER_COMPOSE_FILE=docker/docker-compose.yml

case "$1" in
'rsync')
    ./bin/rsync.sh $2 $3
    exit;
;;
'up')
    if [[ ! -f .env ]]; then
        ./bin/init.sh
    fi

    HOST_UID=$(id -u)
	echo Starting ${folder} services under UID ${HOST_UID}

	docker-compose -p ${folder} -f ${DOCKER_COMPOSE_FILE} up $2 $3
	docker-compose -p ${folder} -f ${DOCKER_COMPOSE_FILE} exec php sh -c "export TERM=xterm; usermod -u $(id -u) app && groupmod -g $(id -g) app"
	docker-compose -p ${folder} -f ${DOCKER_COMPOSE_FILE} exec web sh -c "export TERM=xterm; usermod -u $(id -u) nginx && groupmod -g $(id -g) nginx"
	docker-compose -p ${folder} -f ${DOCKER_COMPOSE_FILE} exec web sh -c "export TERM=xterm; service nginx reload"

	if [[ ! -d vendor ]]; then
	    echo "Vendor directory doesn't exist. Installing dependencies"
	    docker-compose -p ${folder} -f ${DOCKER_COMPOSE_FILE} exec php sh -c "su -c 'cd /code/ && composer install' app;"
	fi

	exit;
;;
'down')
	echo Shutting down ${folder} services
	docker-compose -p ${folder} -f ${DOCKER_COMPOSE_FILE} down --remove-orphans $2 $3
	exit;
;;
'restart')
	./app down
	./app up -d
;;
'stop')
	echo Stop ${folder} services
	docker-compose -p ${folder} -f ${DOCKER_COMPOSE_FILE} stop
	exit;
;;
'build')
	echo Re-build ${folder} services
	docker-compose -p ${folder} -f ${DOCKER_COMPOSE_FILE} build
	exit;
;;
'pull')
	echo "Pull images for ${folder} services"
	docker-compose -p ${folder} -f ${DOCKER_COMPOSE_FILE} pull $2 $3
	exit;
;;
'logs')
	echo Logs ${folder} services
	docker-compose -p ${folder} -f ${DOCKER_COMPOSE_FILE} logs $2
	exit;
;;
'app')
	docker-compose -p ${folder} -f ${DOCKER_COMPOSE_FILE} exec php sh -c "su -c 'cd /code/ && php bin/console $2 $3 $4 $5 $6 $7 $8 $9' app;"
	exit
;;
'composer')
	docker-compose -p ${folder} -f ${DOCKER_COMPOSE_FILE} exec php sh -c "su -c 'cd /code/ && composer $2 $3 $4 $5 $6 $7' app;"
	exit
;;
'exec')
    service=${2:-php}
	echo Entering service $service
    if [[ "$service" = php ]]; then
        docker-compose -p ${folder} -f ${DOCKER_COMPOSE_FILE} exec php sh
    else
        docker-compose -p ${folder} -f ${DOCKER_COMPOSE_FILE} exec ${service} sh -c "export TERM=xterm; exec sh;"
    fi
	exit
;;
esac