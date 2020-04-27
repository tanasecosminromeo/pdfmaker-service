#!/usr/bin/env sh
sed -i -e "s/user = www-data/user = $HOST_UID/g" /usr/local/etc/php-fpm.d/www.conf
sed -i -e "s/group = www-data/group = $HOST_GID/g" /usr/local/etc/php-fpm.d/www.conf

php-fpm
