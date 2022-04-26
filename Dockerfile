FROM ubuntu:20.04

LABEL maintainer="Leandro Conde Trombini"

WORKDIR /usr/share/nginx/envault

ENV TZ=America/Sao_Paulo
ENV LC_ALL=C.UTF-8

SHELL ["/bin/bash", "-c"]

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && apt update \
    && apt install curl unzip cron logrotate gnupg tzdata ca-certificates -y \
    && echo -e "deb https://nginx.org/packages/ubuntu/ focal nginx\ndeb-src https://nginx.org/packages/ubuntu/ focal nginx" > /etc/apt/sources.list.d/nginx.list \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ABF5BD827BD9BF62 \
    && echo -e "deb http://ppa.launchpad.net/ondrej/php/ubuntu focal main\ndeb-src http://ppa.launchpad.net/ondrej/php/ubuntu focal main" > /etc/apt/sources.list.d/ondrej-php.list \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C \
    && apt update \
    && apt upgrade -y \
    && apt install netcat nginx php7.4-fpm php7.4-mbstring php7.4-curl php7.4-xml php7.4-mysql php7.4-redis python3.8-venv -y \
    && sed -i "s/^user.*$/user www-data;/" /etc/nginx/nginx.conf \
    && python3 -m venv /opt/certbot/ \
    && /opt/certbot/bin/pip install --upgrade pip \
    && /opt/certbot/bin/pip install certbot certbot-nginx \
    && ln -s /opt/certbot/bin/certbot /usr/bin/certbot \
    && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && rm composer-setup.php \
    && apt-get clean

# Set the entrypoint to the script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# Add startup script
COPY startup-script.sh /usr/local/bin/startup-script.sh
RUN chmod +x /usr/local/bin/startup-script.sh

# Start script
CMD ["startup-script.sh"]

