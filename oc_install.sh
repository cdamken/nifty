#!/bin/bash

set -e
set -x

apt update

apt upgrade -y

echo "Setting hostname Variable"

my_domain="session.owncloud.works"
echo $my_domain

echo "Setting Hostname"

hostnamectl set-hostname $my_domain
hostname -f

echo "Generating strong Passwords"

sec_admin_pwd=$(openssl rand -base64 18)
echo $sec_admin_pwd > /etc/.sec_admin_pwd.txt
sec_db_pwd=$(openssl rand -base64 18)
echo $sec_db_pwd > /etc/.sec_db_pwd.txt

echo "Creating wrapper script"

FILE="/usr/local/bin/occ"
cat <<EOM >$FILE
#! /bin/bash
cd /var/www/owncloud
sudo -E -u www-data /usr/bin/php /var/www/owncloud/occ "\$@"
EOM

chmod +x $FILE

echo "Installing required packages"

apt install -y \
  apache2 \
  libapache2-mod-php \
  mariadb-server \
  openssl redis-server wget \
  php-imagick php-common php-curl \
  php-gd php-imap php-intl \
  php-json php-mbstring php-mysql \
  php-ssh2 php-xml php-zip \
  php-apcu php-redis php-ldap \
  php-opcache

echo "Installing smb client"

apt-get install -y libsmbclient-dev php-dev php-pear

pecl channel-update pecl.php.net
mkdir -p /tmp/pear/cache
pecl install smbclient-stable
echo "extension=smbclient.so" > /etc/php/7.4/mods-available/smbclient.ini
phpenmod smbclient
systemctl restart apache2

php -m | grep smbclient

echo "Installing recommended packages"

apt install -y \
  unzip bzip2 rsync curl jq \
  inetutils-ping  ldap-utils\
  smbclient

echo "Creating owncloud.conf"

FILE="/etc/apache2/sites-available/owncloud.conf"
cat <<EOM >$FILE
<VirtualHost *:80>
ServerName $my_domain
DirectoryIndex index.php index.html
DocumentRoot /var/www/owncloud
<Directory /var/www/owncloud>
  Options +FollowSymlinks -Indexes
  AllowOverride All
  Require all granted

 <IfModule mod_dav.c>
  Dav off
 </IfModule>

 SetEnv HOME /var/www/owncloud
 SetEnv HTTP_HOME /var/www/owncloud
</Directory>
</VirtualHost>
EOM

a2dissite 000-default
a2ensite owncloud.conf

echo "creating database"

sed -i "/\[mysqld\]/atransaction-isolation = READ-COMMITTED\nperformance_schema = on" /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl start mariadb
mysql -u root -e "CREATE DATABASE IF NOT EXISTS owncloud; \
GRANT ALL PRIVILEGES ON owncloud.* \
  TO owncloud@localhost \
  IDENTIFIED BY '${sec_db_pwd}'";


echo "enabling apache2 modules"

a2enmod dir env headers mime rewrite setenvif
systemctl restart apache2


echo "Getting ownCloud package"

cd /var/www/
wget https://download.owncloud.org/community/owncloud-complete-latest.tar.bz2 && \
tar -xjf owncloud-complete-latest.tar.bz2 && \
chown -R www-data. owncloud

echo "Installing ownCloud"

occ maintenance:install \
    --database "mysql" \
    --database-name "owncloud" \
    --database-user "owncloud" \
    --database-pass ${sec_db_pwd} \
    --data-dir "/var/www/owncloud/data" \
    --admin-user "admin" \
    --admin-pass ${sec_admin_pwd}


echo "Setting Trusted Domains"

my_ip=$(hostname -I|cut -f1 -d ' ')
occ config:system:set trusted_domains 1 --value="$my_ip"
occ config:system:set trusted_domains 2 --value="$my_domain"

echo "Configuring Cronjobs"

occ background:cron

echo "*/15  *  *  *  * /var/www/owncloud/occ system:cron" \
  | sudo -u www-data -g crontab tee -a \
  /var/spool/cron/crontabs/www-data
echo "0  2  *  *  * /var/www/owncloud/occ dav:cleanup-chunks" \
  | sudo -u www-data -g crontab tee -a \
  /var/spool/cron/crontabs/www-data


echo "Configuring Caching and File Locking"

occ config:system:set \
   memcache.local \
   --value '\OC\Memcache\APCu'
occ config:system:set \
   memcache.locking \
   --value '\OC\Memcache\Redis'
occ config:system:set \
   redis \
   --value '{"host": "127.0.0.1", "port": "6379"}' \
   --type json


echo "Configuring Log Rotate"

FILE="/etc/logrotate.d/owncloud"
sudo cat <<EOM >$FILE
/var/www/owncloud/data/owncloud.log {
  size 10M
  rotate 12
  copytruncate
  missingok
  compress
  compresscmd /bin/gzip
}
EOM


cd /var/www/
chown -R www-data. owncloud

occ -V
echo "Your Admin password: "$sec_admin_pwd
echo "Your Database Password: "$sec_db_pwd
echo "your ownCloud is accessable under: "$my_domain

