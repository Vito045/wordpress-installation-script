#!/bin/bash

PACKAGE_NAME=''
PACKAGE_INSTALLATION_NAME=''

UTILITY_DESTROYER_LINK='http://rpms.remirepo.net/enterprise/remi-release-7.rpm'

installation_init() {
 PACKAGE_NAME="${1}"
 shift
 PACKAGE_INSTALLATION_NAMES=( "${@}" )
 
 #if [[ -n "${PACKAGE_NAME}" || -n "${PACKAGE_INSTALLATION_NAME}" ]]
 #then
 # 
 #fi
}

installation_ask(){
 echo "One of the packages required for wordpress installation wasn't found: ${PACKAGE_NAME}."

 while true;
 do
  read -p "Do you wish to install this package? (y/n))" yn
  case $yn in
   [Yy]* ) install; break ;;
   [Nn]* ) exit ;;
   * ) echo "Please answer yes or no." ;;
  esac
 done
}

install() {
 for PACKAGE in "${PACKAGE_INSTALLATION_NAMES[@]}"
 do
  echo
  yum install -y ${PACKAGE}
  echo

  if [[ "${?}" -ne 0 ]]
  then
   echo "Something went wrong while installation of ${PACKAGE}. Try to finx the problem and run script again" >&2
   exit 1
   fi
  echo
 done
 echo "Package ${PACKAGE_NAME} was succesfully installed."
 echo
}

package_check() {
 for PACKAGE in "${PACKAGE_INSTALLATION_NAMES[@]}"
 do
  if [[ "${PACKAGE}" == "${UTILITY_DESTROYER_LINK}" ]]; then PACKAGE='remi'; fi

  local PACKAGE_COUNT=$(rpm -qa | grep $PACKAGE | wc -l)
  #echo "${PACKAGE}: ${PACKAGE_COUNT}"
  if [ ${PACKAGE_COUNT} -lt 1 ]
  then
   return 0
  else
    continue
  fi
 done
 false
}

# Check if user has superuser priviliges
if [[ "${UID}" -ne 0 ]]
then
 echo "Please run as a root or use sudo."
 exit 1
fi

echo "Checking installed packages..."

# Check if apache is installed
installation_init 'apache' 'httpd'

if package_check
then
 installation_ask
 systemctl enable httpd.service
fi

# Check if MySQL is installed
installation_init 'MySQL' 'mariadb' 'mariadb-server'

if package_check
then
 installation_ask
fi
systemctl start mariadb
mysql_secure_installation
systemctl enable mariadb.service


# Check if Remi and Epel adre installed
installation_init 'Remi and Epe' 'epel-release' 'yum-utils' 'http://rpms.remirepo.net/enterprise/remi-release-7.rpm'

if package_check
then
 installation_ask
 yum-config-manager --enable remi-php70
fi

# Install or update php
installation_init 'PHP 7' 'php' 'php-mysql'

# if [ package_check ] && [ ! $(php -v | cut -d ' ' -f 2 | head -n1 | cut -d '.' -f 1) = '7' ]
installation_ask
systemctl restart httpd

cd /var/www/html
wget https://wordpress.org/latest.tar.gz
tar xvzf latest.tar.gz
mv /var/www/html/wordpress/* /var/www/html

mysql -u root -p --execute="CREATE DATABASE wordpress; GRANT ALL PRIVILEGES on wordpress.* to 'wordpress_user'@'localhost' identified by 'wordpress_pw'; FLUSH PRIVILEGES;"

mv wp-config-sample.php wp-config.php

sed -i "s|'database_name_here'|'wordpress'|" wp-config.php
sed -i "s|'username_here'|'wordpress_user'|" wp-config.php
sed -i "s|'password_here'|'wordpress_pw'|" wp-config.php

systemctl restart httpd



