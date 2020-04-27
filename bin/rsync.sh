#!/usr/bin/env bash

folder=${PWD##*/}

read_var() {
    MY_VAR=$(grep $1 .env | xargs)
    echo ${MY_VAR#*=}
}

HOST_UID=$(read_var HOST_UID)

if [ $HOST_UID -ne $(id -u) ]; then
    echo "This server can be started just by UID $HOST_UID "
    exit;
fi

case "$1" in
'rsync')
    ./bin/rsync.sh $2 $3
    exit;
;;
'up')
    HOST_UID=$(id -u)
	echo Starting $folder services under UID $HOST_UID

	docker-compose -p $folder -f docker/docker-compose.yml up $2 $3
	docker-compose -p $folder -f docker/docker-compose.yml exec php bash -c "export TERM=xterm; usermod -u $(id -u) app && groupmod -g $(id -g) app"
	docker-compose -p $folder -f docker/docker-compose.yml exec web sh -c "export TERM=xterm; usermod -u $(id -u) nginx && groupmod -g $(id -g) nginx"
	docker-compose -p $folder -f docker/docker-compose.yml exec web sh -c "export TERM=xterm; service nginx reload"
	exit;
;;
'down')
	echo Shutting down $folder services
	docker-compose -p $folder -f docker/docker-compose.yml down --remove-orphans $2 $3
	exit;
;;
'live')
    echo "Making everything live"
	git pull
	git push
	git checkout prod
	git merge master
	git push
	git checkout master

	ssh -t viata@hzde-dev -p 2218 "cd /home/viata/viata.org/; git pull"

	echo "All live in theory"
	exit;
;;
'restart')
	./app down
	./app up -d
;;
'stop')
	echo Stop $folder services
	docker-compose -p $folder -f docker/docker-compose.yml stop
	exit;
;;
'build')
	echo Re-build $folder services
	docker-compose -p $folder -f docker/docker-compose.yml build
	exit;
;;
'logs')
	echo Logs $folder services
	docker-compose -p $folder -f docker/docker-compose.yml logs $2
	exit;
;;
'app')
	docker-compose -p $folder -f docker/docker-compose.yml exec php bash -c "su -c 'cd /code/ && php bin/console $2 $3 $4 $5 $6 $7 $8 $9' app;"
	exit
;;
'composer')
	docker-compose -p $folder -f docker/docker-compose.yml exec php bash -c "su -c 'cd /code/ && composer $2 $3 $4 $5 $6 $7' app;"
	exit
;;
'yarn')
	docker-compose -p $folder -f docker/docker-compose.yml exec php bash -c "su -c 'cd /code/ && yarn $2 $3 $4 $5 $6 $7' app;"
	exit
;;
'exec')
    service=${2:-php}
	echo Entering service $service
    if [ "$service" = php ]; then
        docker-compose -p $folder -f docker/docker-compose.yml exec php bash
    else
        docker-compose -p $folder -f docker/docker-compose.yml exec $service bash -c "export TERM=xterm; exec bash;"
    fi
	exit
;;
'cmd')
    docker-compose -p $folder -f docker/docker-compose.yml exec php bash -c "su -c 'cd /code/ && php -f action/$2.php $3 $4 $5 $6' app;"
;;
'backup')
	filename=${PWD##*/}-$(date +"%y%m%d-%H%k%S").tgz

	if [ -f 'backup.sql' ] ; then
		rm -rf 'backup.sql'
	fi

	USER_ID=$(id -u)
	GROUP_ID=$(id -g)
	MYSQL_ROOT_PASSWORD=$(read_var MYSQL_ROOT_PASSWORD)

	docker-compose -p $folder -f docker/docker-compose.yml exec db bash -c "mysqldump -v -p$MYSQL_ROOT_PASSWORD --all-databases > /code/backup.sql; chown $USER_ID:$GROUP_ID /code/backup.sql"
	tar cvzf $filename --exclude "./*.tgz" --exclude "*.tgz" --exclude "./public/wp-content/updraft" .
;;
esac