#!/bin/sh
set -e

# Read database credentials from config.json
DB_SCHEMA=$(grep -o '"schema": *"[^"]*"' /var/www/html/config.json | cut -d'"' -f4)
DB_USER=$(grep -o '"username": *"[^"]*"' /var/www/html/config.json | cut -d'"' -f4)
DB_PASS=$(grep -o '"password": *"[^"]*"' /var/www/html/config.json | cut -d'"' -f4)

# Use defaults if empty
DB_SCHEMA=${DB_SCHEMA:-kptv}
DB_USER=${DB_USER:-kptv}
DB_PASS=${DB_PASS:-kptv123}

# Initialize MySQL if needed
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MySQL database..."
    /usr/bin/mariadb-install-db --user=mysql --datadir=/var/lib/mysql
    
    /usr/bin/mariadbd --user=mysql --datadir=/var/lib/mysql &
    MYSQL_PID=$!
    sleep 5
    
    /usr/bin/mariadb -e "CREATE DATABASE IF NOT EXISTS ${DB_SCHEMA};"
    /usr/bin/mariadb -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
    /usr/bin/mariadb -e "GRANT ALL PRIVILEGES ON ${DB_SCHEMA}.* TO '${DB_USER}'@'localhost';"
    /usr/bin/mariadb -e "FLUSH PRIVILEGES;"
    
    echo "Importing database schema..."
    /usr/bin/mariadb ${DB_SCHEMA} < /schema.sql
    
    kill $MYSQL_PID
    wait $MYSQL_PID
fi

# Start all services
echo "Starting services..."
/usr/bin/mariadbd --user=mysql --datadir=/var/lib/mysql &
crond -f -l 2 &
php-fpm &
exec nginx -g 'daemon off;'