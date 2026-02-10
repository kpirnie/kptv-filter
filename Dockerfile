FROM docker.io/library/php:8.4-fpm-alpine

# Install nginx, MariaDB (MySQL replacement), cron, and required extensions
RUN apk add --no-cache \
    nginx \
    mariadb \
    mariadb-client \
    dcron \
    && docker-php-ext-install pdo_mysql mysqli opcache

# Copy nginx configuration
COPY config/nginx.conf /etc/nginx/http.d/default.conf
# Copy the db schema
COPY config/schema.sql /schema.sql

# Copy application
COPY site/ /var/www/html/

# MySQL data directory
RUN mkdir -p /run/mysqld /var/lib/mysql \
    && chown -R mysql:mysql /run/mysqld /var/lib/mysql

# Startup script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

VOLUME ["/var/lib/mysql"]

ENTRYPOINT ["/entrypoint.sh"]