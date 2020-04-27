FROM php:7.4.3-fpm-alpine

RUN apk update \
    && apk add --no-cache \
        xvfb \
        # Additionnal dependencies for better rendering
        ttf-freefont \
        fontconfig \
        dbus \
        #this will generate the pdfs
        wkhtmltopdf \
        #this will be used for compression
        ghostscript \
        #useful to not run PHP as root
        shadow \
    && useradd -ms /bin/sh app \
    && echo "upload_max_filesize = 100M;" > /usr/local/etc/php/conf.d/uploads.ini \
    && echo "post_max_size = 100M;" > /usr/local/etc/php/conf.d/uploads.ini \
    && rm -rf /var/cache/apk/* \
    && chmod +x /usr/bin/crontab \
    && ln -s /usr/local/bin/php /usr/bin/php \
    && chmod +x /usr/bin/php

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

WORKDIR /code

# Set up the owner and run php-fpm
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]