#! /bin/bash

# Evironment variables
FILE=./.env

# Check if .env file exists and other setups
echo "### CHECK .env FILE"
if ! test -f "$FILE";
then
    cp -p .env.example .env
    echo "# COPIED .env FILE"
else
    echo "# .env FILE EXIST"
fi


# Check database environment variables are set
echo "### CHECK DATABASE SETS"
if [ ! -z "$LARAVEL_DB_PASSWORD" ]
then
    sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$LARAVEL_DB_PASSWORD/" .env
    echo "# COPIED DB_PASSWORD FROM ENVIRONMENT"
else
    #sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$(date +%s | sha256sum | base64 | head -c 32 ; echo)/" .env
    #echo "# GENERATE RANDOM DB_PASSWORD"
    echo "MISSING LARAVEL_DB_PASSWORD ENV"
    exit 1
fi
if [ ! -z "$LARAVEL_DB_NAME" ]
then
    sed -i "s/DB_DATABASE=.*/DB_DATABASE=$LARAVEL_DB_NAME/" .env
    echo "# COPIED DB_DATABASE FROM ENVIRONMENT"
else
   echo "# MISSING LARAVEL_DB_NAME ENV"
   exit 1
fi
if [ ! -z "$LARAVEL_DB_HOST" ]
then
   sed -i "s/DB_HOST=.*/DB_HOST=$LARAVEL_DB_HOST/" .env
   echo "# COPIED DB_HOST FROM ENVIRONMENT"
else
   echo "# MISSING LARAVEL_DB_HOST ENV"
   exit 1
fi

# Check redis environment variables are set
echo "### CHECK REDIS SETS"
if [ ! -z "$LARAVEL_REDIS_HOST" ]
then
   sed -i "s/REDIS_HOST=.*/REDIS_HOST=$LARAVEL_REDIS_HOST/" .env
   echo "# COPIED REDIS_HOST FROM ENVIRONMENT"
else
   echo "# MISSING LARAVEL_REDIS_HOST ENV"
   exit 1
fi
if [ ! -z "$LARAVEL_REDIS_PASSWORD" ]
then
    sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=$LARAVEL_REDIS_PASSWORD/" .env
    echo "# COPIED REDIS_PASSWORD FROM ENVIRONMENT"
else
    sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=" .env
    echo "# LEAVE REDIS_PASSWORD EMPTY"
fi


# Set APP_ENV
echo "### CHECK APP_ENV"
if [ -z "$LARAVEL_ENV" ]
then
   echo "APP_ENV="$LARAVEL_ENV >> .env
   echo "# COPIED APP_ENV FROM ENVIRONMENT"
else
   echo "APP_ENV=production"
   echo "# SET APP_ENV=production AS DEFAULT"
fi

# Install Application and run migrations
echo "### RUN COMPOSER INSTALL"
composer install --no-interaction

# Check Application key is set
echo "### CHECK IF APP_KEY EXIST"
if grep -w "APP_KEY=" .env;
then
    php artisan key:generate
    echo "# NEW APP_KEY GENERATED"
else
    echo "# APP_KEY ALREADY CONFIGURED"
fi

# Install Migrations
echo "### RUN ARTISAN MIGRATION"
until nc -v -z mysql 3306
do
   echo "# WAITING DATABASE 5sec"
   sleep 5
done
echo "# DATABASE CONNECTION OK"
php artisan migrate --force

#Set variables here
LARAVEL_OWNER=root # <-- owner (user)
LARAVEL_WS_GROUP=www-data # <-- WebServer group
LARAVEL_ROOT=/usr/share/nginx/envault # <-- Laravel root directory

# BEGIN Fix Laravel Permissions Script
echo "### FIX LARAVEL FILE STRUCTURE PERMISSIONS"

# Adding owner to web server group
usermod -a -G ${LARAVEL_WS_GROUP} ${LARAVEL_OWNER}

# Set files owner/group
chown -R ${LARAVEL_OWNER}:${LARAVEL_WS_GROUP} ${LARAVEL_ROOT}

# Set correct permissions for directories 
find ${LARAVEL_ROOT} -type f -exec chmod 644 {} \;

# Set correct permissions for files 
find ${LARAVEL_ROOT} -type d -exec chmod 755 {} \;

# Set webserver group for storage + cache folders
chgrp -R ${LARAVEL_WS_GROUP} ${LARAVEL_ROOT}/storage ${LARAVEL_ROOT}/bootstrap/cache

# Set correct permissions for storage + cache folders
chmod -R ug+rwx ${LARAVEL_ROOT}/storage ${LARAVEL_ROOT}/bootstrap/cache

# END Fix Laravel Permissions Script

# Check if crontab is set
if ! crontab -l | grep -q "certbot renew";
then
    (crontab -l ; echo "0 0 1 * * certbot renew --post-hook \"service nginx reload\"") | crontab -
fi

# Check if domain is set
echo "### CHECK DOMAIN USAGE"
touch /var/log/nginx/access.log
touch /var/log/nginx/error.log
ln -sf /dev/stdout /var/log/nginx/access.log && ln -sf /dev/stderr /var/log/nginx/error.log
if [ ! -z "$LARAVEL_URL_PROTOCOL" ] || [ ! -z "$LARAVEL_URL_HOSTNAME" ];
then
    echo "# Start without domain"
    echo # Check TLS SelfSigned Certificate
    SSL_SELFSIGNED_KEY=/etc/ssl/private/nginx-selfsigned.key
    SSL_SELFSIGNED_CERT=/etc/ssl/certs/nginx-selfsigned.crt
    if [ ! -f "$SSL_SELFSIGNED_KEY" ] || [ ! -f "$SSL_SELFSIGNED_KEY" ]
    then
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/C=BR/ST=Sao Paulo/L=Sao Paulo/O=SRE/OU=IT Department/CN="
    fi
    sed -i "s/APP_URL=.*/APP_URL=$LARAVEL_URL_PROTOCOL:\/\/$LARAVEL_URL_HOSTNAME/" .env
    service php7.4-fpm start && service nginx start && ps auxw
else
    echo "# Start with domain"

    service php7.4-fpm start && service nginx start && certbot --nginx -d $1 -m $2 --agree-tos --no-eff-email --non-interactive && service nginx reload && ps auxw
fi

echo "### END STARTUP SCRIPT"
echo "### START LOOP PROCESS"
# Loop to show process and maintain script execution
while true
do
 sleep 60
 date
 service nginx status
 service php7.4-fpm status
 echo "----------"
done