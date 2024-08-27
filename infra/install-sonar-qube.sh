#!/bin/bash
# run this script as root via the syntax below
# curl -s url to this script | bash /dev/stdin the_password the_backup

if [ "$1" != "" ]; then
  export MY_PWD="$1"
else
  export MY_PWD="changeme"
fi

if [ "$2" != "" ]; then
  export MY_BAK="$2"
fi

export MY_USER="sonarqube"
useradd $MY_USER
echo "$MY_PWD" | passwd $MY_USER --stdin
usermod -aG wheel $MY_USER
su -m $MY_USER
cd /home/$MY_USER

# login as sonarqube
# echo "$MY_PWD" | sudo -S yum install -y epel-release
# sudo yum update -y
echo "$MY_PWD" | sudo -S yum install -y java-1.8.0-openjdk wget unzip

echo "$MY_PWD" | sudo -S rpm -Uvh https://download.postgresql.org/pub/repos/yum/9.6/redhat/rhel-7-x86_64/pgdg-centos96-9.6-3.noarch.rpm
sudo yum -y install postgresql96-server postgresql96-contrib
sudo /usr/pgsql-9.6/bin/postgresql96-setup initdb

sudo sed -i -e 's/peer/trust/g' /var/lib/pgsql/9.6/data/pg_hba.conf
sudo sed -i -e 's/ident/md5/g' /var/lib/pgsql/9.6/data/pg_hba.conf

sudo systemctl start postgresql-9.6
sudo systemctl enable postgresql-9.6

psql -U postgres -c "CREATE USER sonar WITH ENCRYPTED password '$MY_PWD';"
psql -U postgres -c "CREATE DATABASE sonar OWNER sonar;"

wget https://sonarsource.bintray.com/Distribution/sonarqube/sonarqube-6.5.zip
sudo unzip sonarqube-6.5.zip -d /opt
sudo mv /opt/sonarqube-6.5 /opt/sonarqube

sudo sed -i -e 's/#sonar.jdbc.username=/sonar.jdbc.username=sonar/g' /opt/sonarqube/conf/sonar.properties
sudo sed -i -e 's/#sonar.jdbc.password=/sonar.jdbc.password=huawei123/g' /opt/sonarqube/conf/sonar.properties
sudo sed -i -e 's/#sonar.jdbc.url=jdbc:postgresql/sonar.jdbc.url=jdbc:postgresql/g' /opt/sonarqube/conf/sonar.properties

echo "[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking

ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop

User=root
Group=root
Restart=always

[Install]
WantedBy=multi-user.target" | sudo tee -a /etc/systemd/system/sonar.service

if [ "$MY_BAK" != "" ]; then
  wget $MY_BAK -O backup.zip
  unzip backup.zip
  cd cicd*
  cd sonarqube
  psql -U postgres sonar < dbdump.sql
  echo "$MY_PWD" | sudo -S mv plugins/* /opt/sonarqube/extensions/plugins/
fi

# sudo systemctl start sonar
sudo systemctl enable sonar
sudo reboot