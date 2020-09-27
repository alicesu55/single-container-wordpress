FROM mariadb:10.5
LABEL maintainer "Alice Su <toalice@protonmail.com>" architecture="AMD64/x86_64"
LABEL mariadb-version="10.5"

ARG COMMIT_TIME
ARG CI_APPLICATION_TAG_SHORT
LABEL org.label-schema.build-date="$COMMIT_TIME" \
      org.label-schema.name="single-container-wordpress" \
      org.label-schema.description="Running multiple wordpress instances in a single container" \
      org.label-schema.vcs-ref="$CI_APPLICATION_TAG_SHORT" \
      org.label-schema.vcs-url="https://github.com/alicesu55/single-container-wordpress" \
      org.label-schema.vendor="Alice Su's Studio" \
      org.label-schema.version="0.1" \
      org.label-schema.schema-version="0.1"

# Modify the base image, see its source: https://github.com/docker-library/mariadb/tree/master/10.3
RUN mv /usr/local/bin/docker-entrypoint.sh /usr/local/bin/mariadb-entrypoint.sh


# persistent / runtime deps
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
# From wordpress
        libfreetype6-dev \
		libjpeg-dev \
		libmagickwand-dev \
		libpng-dev \
# maintained here
		apache2 \
		cron \
		curl \
		libapache2-mod-php \
		php \
		php-mysql \
        python3 \
        python3-pip \
        supervisor \
		unzip \
	; \
	rm -rf /var/lib/apt/lists/*

# https://wordpress.org/support/article/editing-wp-config-php/#configure-error-logging
RUN { \
# https://www.php.net/manual/en/errorfunc.constants.php
# https://github.com/docker-library/wordpress/issues/420#issuecomment-517839670
		echo 'error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
		echo 'display_errors = Off'; \
		echo 'display_startup_errors = Off'; \
		echo 'log_errors = On'; \
		echo 'error_log = /dev/stderr'; \
		echo 'log_errors_max_len = 1024'; \
		echo 'ignore_repeated_errors = On'; \
		echo 'ignore_repeated_source = Off'; \
		echo 'html_errors = Off'; \
	} > /etc/php/7.4/apache2/conf.d/10-error-logging.ini

RUN set -eux; \
	a2enmod rewrite expires; \
	\
# https://httpd.apache.org/docs/2.4/mod/mod_remoteip.html
	a2enmod remoteip; \
	{ \
		echo 'RemoteIPHeader X-Forwarded-For'; \
# these IP ranges are reserved for "private" use and should thus *usually* be safe inside Docker
		echo 'RemoteIPTrustedProxy 10.0.0.0/8'; \
		echo 'RemoteIPTrustedProxy 172.16.0.0/12'; \
		echo 'RemoteIPTrustedProxy 192.168.0.0/16'; \
		echo 'RemoteIPTrustedProxy 169.254.0.0/16'; \
		echo 'RemoteIPTrustedProxy 127.0.0.0/8'; \
	} > /etc/apache2/conf-available/remoteip.conf; \
	a2enconf remoteip; \
# https://github.com/docker-library/wordpress/issues/383#issuecomment-507886512
# (replace all instances of "%h" with "%a" in LogFormat)
	find /etc/apache2 -type f -name '*.conf' -exec sed -ri 's/([[:space:]]*LogFormat[[:space:]]+"[^"]*)%h([^"]*")/\1%a\2/g' '{}' +

ENV WORDPRESS_VERSION 5.5.1
ENV WORDPRESS_SHA1 d3316a4ffff2a12cf92fde8bfdd1ff8691e41931

RUN set -ex; \
	curl -o wordpress.tar.gz -fSL "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz"; \
	echo "$WORDPRESS_SHA1 *wordpress.tar.gz" | sha1sum -c -; \
# upstream tarballs include ./wordpress/ so this gives us /usr/src/wordpress
	tar -xzf wordpress.tar.gz -C /usr/src/; \
	rm wordpress.tar.gz; \
	chown -R www-data:www-data /usr/src/wordpress; \
# pre-create wp-content (and single-level children) for folks who want to bind-mount themes, etc so permissions are pre-created properly instead of root:root
	mkdir wp-content; \
	for dir in /usr/src/wordpress/wp-content/*/; do \
		dir="$(basename "${dir%/}")"; \
		mkdir "wp-content/$dir"; \
	done; \
	chown -R www-data:www-data wp-content; \
	chmod -R 777 wp-content

RUN pip3 install pyyaml

RUN rm /etc/apache2/sites-enabled/000-default.conf
RUN rm -rf /var/www/html/*

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" ;\
	unzip -qq awscliv2.zip; \
	./aws/install; \
	/usr/local/bin/aws --version

COPY entrypoint.py /usr/local/bin/
COPY init_mariadb.sh /usr/local/bin/
COPY s3_backup.sh /usr/local/bin/
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY wp-docker-config.yml /etc/wp-docker-config.yml
COPY setup-wp.sh /usr/local/bin/
COPY init_from_s3_backup.sh /usr/local/bin/
COPY mem /etc/mem
COPY conf/apache2.conf /etc/apache2/apache2.conf

ENTRYPOINT [ "entrypoint.py" ]
