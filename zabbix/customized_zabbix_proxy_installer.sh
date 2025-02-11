ProxyTitle=$1
#yum --disablerepo=mariadb install -y wget make gcc libxml2-devel net-snmp-devel libevent-devel curl-devel pcre* perl-JSON.noarch perl-Test-Simple libaio numactl
yum install -y wget make gcc libxml2-devel net-snmp-devel libevent-devel curl-devel pcre* perl-JSON.noarch perl-Test-Simple libaio numactl
if [ $? -ne 0 ]; then
  echo "Error while installing packages."
  exit 1
fi

#Uninstall Mysql
remove_package_list=`rpm -qa | grep "^mysql"`
yum remove -y $remove_package_list
rm -rf /var/lib/mysql/
rm -rf /data/mysql/
rm -rf /var/log/mysql*
rm -rf /etc/my.cnf

#Install MySQL8
#wget https://downloads.mysql.com/archives/get/p/23/file/mysql-8.0.27-1.el7.x86_64.rpm-bundle.tar
wget https://downloads.mysql.com/archives/get/p/23/file/mysql-8.0.27-1.el8.x86_64.rpm-bundle.tar
mkdir /usr/src/mysql8
tar -xvf mysql-8.0.27-1.el8.x86_64.rpm-bundle.tar -C /usr/src/mysql8
cd /usr/src/mysql8
yum remove mysql-libs
rpm -ivh *.rpm
rpm -Uvh *.rpm
systemctl start mysqld;sudo systemctl enable mysqld

#Moving & configuring mysql
#Check dir for MySQL
mysqldir="/var/lib"
checkdir=`sudo ls /data`
if [[ $checkdir != null ]]
then
        mysqldir="/data"
        #Moving & configuring mysql
        sudo mv /var/lib/mysql /data/
        sudo sed -i '/^datadir=/c\datadir=/data/mysql/' /etc/my.cnf
        sudo sed -i '/^socket=/c\socket=/data/mysql/mysql.sock' /etc/my.cnf
        echo "Directory changed from /var/lib to /data."
else
        echo "No directory of /data."
fi

sudo echo "" >> /etc/my.cnf
sudo echo "validate_password.policy=0" >> /etc/my.cnf
sudo echo "validate_password.length=4" >> /etc/my.cnf
sudo echo "skip-log-bin" >> /etc/my.cnf
sudo echo "binlog_expire_logs_seconds=86400" >> /etc/my.cnf
sudo echo "" >> /etc/my.cnf
sudo echo "[client]" >> /etc/my.cnf
sudo echo "socket=$mysqldir/mysql/mysql.sock" >> /etc/my.cnf
sudo systemctl restart mysqld

tmp_pwd=`cat /var/log/mysqld.log | grep "temporary password" | tail -1 | rev | cut -d" " -f1 | rev`
echo $tmp_pwd
sudo mysql -uroot -p"$tmp_pwd" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'xxxxxxxxx'" --connect-expired-password
sudo mysql -uroot -pxxxxxxxxxx -e "create user 'zabbix_proxy'@localhost identified with caching_sha2_password by 'xxxxxxxx';flush privileges;"
sudo mysql -uroot -pxxxxxxxxxx -e "create database ${ProxyTitle}_proxy_v602_10051 character set utf8;"
sudo mysql -uroot -pxxxxxxxxxx -e "create database ${ProxyTitle}_proxy_v602_10053 character set utf8;"
sudo mysql -uroot -pxxxxxxxxxx -e "grant all on ${ProxyTitle}_proxy_v602_10051.* to 'zabbix_proxy'@'localhost';"
sudo mysql -uroot -pxxxxxxxxxx -e "grant all on ${ProxyTitle}_proxy_v602_10053.* to 'zabbix_proxy'@'localhost';flush privileges;"


#Install Zabbix
groupadd zabbix
useradd zabbix -g zabbix -s /sbin/nologin

yum update -y
mkdir /opt/zabbix_proxy_v602
wget https://cdn.zabbix.com/zabbix/sources/stable/6.0/zabbix-6.0.2.tar.gz
tar -zxvf zabbix-6.0.2.tar.gz -C /tmp/
cd /tmp/zabbix-6.0.2/
./configure --prefix=/opt/zabbix_proxy_v602 --enable-agent --enable-proxy --with-mysql --enable-ipv6 --with-net-snmp --with-libcurl --with-libxml2;sudo make && sudo make install
mysql -uroot -pxxxxxxx "$ProxyTitle"_proxy_v602_10051 < /tmp/zabbix-6.0.2/database/mysql/schema.sql
mysql -uroot -pxxxxxxx "$ProxyTitle"_proxy_v602_10053 < /tmp/zabbix-6.0.2/database/mysql/schema.sql

mkdir /opt/tools
mkdir /opt/tools/zabbix_userparameter
mkdir /tmp/"$ProxyTitle"_proxy_v602_10051
mkdir /tmp/"$ProxyTitle"_proxy_v602_10053
mkdir /tmp/zabbix
chown zabbix:zabbix /tmp/"$ProxyTitle"_proxy_v602_10*
cd /usr/src/
wget https://fping.org/dist/fping-4.0.tar.gz
tar -zxvf fping-4.0.tar.gz
cd fping-4.0
./configure
make && make install
cd /usr/local/sbin/
chmod 4710 fping

#Configuration djustments for Zabbix Proxy 10051
proxy51="/opt/zabbix_proxy_v602/etc/"$ProxyTitle"_proxy_v602_10051.conf"
proxy53="/opt/zabbix_proxy_v602/etc/"$ProxyTitle"_proxy_v602_10053.conf"
agent="/opt/zabbix_proxy_v602/etc/zabbix_agentd.conf"
cp -ap /opt/zabbix_proxy_v602/etc/zabbix_proxy.conf $proxy51
sed -i "/^Server=/c\Server=xxx.xxx.xxx.xxx" $proxy51
sed -i "/^Hostname=/c\Hostname="$ProxyTitle"_proxy_v602_10051" $proxy51
sed -i "/^# ListenPort=10051/c\ListenPort=10051" $proxy51
sed -i "/^LogFile=/c\LogFile=/tmp/"$ProxyTitle"_proxy_v602_10051.log" $proxy51
sed -i "/^PidFile=/c\PidFile=/tmp/"$ProxyTitle"_proxy_v602_10051.pid" $proxy51
sed -i "/^# PidFile=/c\PidFile=/tmp/"$ProxyTitle"_proxy_v602_10051.pid" $proxy51
sed -i "/^# SocketDir=/c\SocketDir=/tmp/"$ProxyTitle"_proxy_v602_10051" $proxy51
sed -i "/^DBName=/c\DBName="$ProxyTitle"_proxy_v602_10051" $proxy51
sed -i "/^DBUser=/c\DBUser=zabbix_proxy" $proxy51
sed -i "/^# DBPassword=/c\DBPassword=xxxxxxxxx" $proxy51
sed -i "/^# DBSocket=/c\DBSocket=/data/mysql/mysql.sock" $proxy51
sed -i "/^# ProxyLocalBuffer=/c\ProxyLocalBuffer=0" $proxy51
sed -i "/^# ProxyOfflineBuffer=/c\ProxyOfflineBuffer=4" $proxy51
sed -i "/^# ConfigFrequency=/c\ConfigFrequency=60" $proxy51
sed -i "/^# DataSenderFrequency=/c\DataSenderFrequency=10" $proxy51
sed -i "/^# StartPollers=/c\StartPollers=60" $proxy51
sed -i "/^# StartPreprocessors=/c\StartPreprocessors=3" $proxy51
sed -i "/^# StartPollersUnreachable=/c\StartPollersUnreachable=1" $proxy51
sed -i "/^# StartTrappers=/c\StartTrappers=10" $proxy51
sed -i "/^# StartPingers=/c\StartPingers=40" $proxy51
sed -i "/^# StartDiscoverers=/c\StartDiscoverers=10" $proxy51
sed -i "/^# StartHTTPPollers=/c\StartHTTPPollers=1" $proxy51
sed -i "/^# HousekeepingFrequency=/c\HousekeepingFrequency=0" $proxy51
sed -i "/^# CacheSize=/c\CacheSize=1024M" $proxy51
sed -i "/^# StartDBSyncers=/c\StartDBSyncers=4" $proxy51
sed -i "/^# HistoryCacheSize=/c\HistoryCacheSize=16M" $proxy51
sed -i "/^# HistoryIndexCacheSize=/c\HistoryIndexCacheSize=64M" $proxy51
sed -i "/^Timeout=/c\Timeout=30" $proxy51
sed -i "/^# UnreachablePeriod=/c\UnreachablePeriod=45" $proxy51
sed -i "/^# UnreachableDelay=/c\UnreachableDelay=15" $proxy51
sed -i "/^# FpingLocation=/c\FpingLocation=/usr/local/sbin/fping" $proxy51

#Configuration adjustments for Zabbix Proxy 10053
cp -ap $proxy51 $proxy53
sed -i "/^Server=/c\Server=103.247.205.130" $proxy53
sed -i "/^ListenPort=/c\ListenPort=10053" $proxy53
sed -i "/^LogFile=/c\LogFile=/tmp/"$ProxyTitle"_proxy_v602_10053.log" $proxy53
sed -i "/^PidFile=/c\PidFile=/tmp/"$ProxyTitle"_proxy_v602_10053.pid" $proxy53
sed -i "/^SocketDir=/c\SocketDir=/tmp/"$ProxyTitle"_proxy_v602_10053" $proxy53
sed -i "/^DBName=/c\DBName="$ProxyTitle"_proxy_v602_10053" $proxy53
sed -i "/^StartPingers=/c\StartPingers=20" $proxy53

#Configuration adjustments for Zabbix Agent Config
ip=`ifconfig | grep inet | grep broadcast | cut -d' ' -f10`
hostname=`hostname`
sed -i "/^# PidFile=/c\PidFile=/tmp/zabbix_agentd.pid" $agent
sed -i "/^# LogFileSize=/c\LogFileSize=1" $agent
sed -i "/^Server=/c\Server=$ip" $agent
sed -i "/^ServerActive=/c\ServerActive=$ip:10051,$ip:10053" $agent
sed -i "/^Hostname=/c\Hostname=$hostname" $agent
sed -i "/^# Timeout=/c\Timeout=30" $agent
sed -i "/^# Include=/c\Include=/opt/tools/zabbix_userparameter/*.conf" $agent

#Starting Zabbix Proxies & Agent
/opt/zabbix_proxy_v602/sbin/zabbix_proxy -c /opt/zabbix_proxy_v602/etc/"$ProxyTitle"_proxy_v602_10051.conf
/opt/zabbix_proxy_v602/sbin/zabbix_proxy -c /opt/zabbix_proxy_v602/etc/"$ProxyTitle"_proxy_v602_10053.conf
/opt/zabbix_proxy_v602/sbin/zabbix_agentd -c /opt/zabbix_proxy_v602/etc/zabbix_agentd.conf

#Setting up partition
mysql -uroot -pxxxxxxxxx ${ProxyTitle}_proxy_v602_10051 < /home/jenkins/partition.sql
mysql -uroot -pxxxxxxxxx ${ProxyTitle}_proxy_v602_10053 < /home/jenkins/partition.sql
mysql -uroot -pxxxxxxxxx ${ProxyTitle}_proxy_v602_10051 -e "ALTER TABLE \`proxy_history\` DROP PRIMARY KEY , ADD PRIMARY KEY ( \`id\`,\`clock\` );"
mysql -uroot -pxxxxxxxxx ${ProxyTitle}_proxy_v602_10053 -e "ALTER TABLE \`proxy_history\` DROP PRIMARY KEY , ADD PRIMARY KEY ( \`id\`,\`clock\` );"
mysql -uroot -pxxxxxxxxx ${ProxyTitle}_proxy_v602_10051 -e "CALL partition_maintenance_all('${ProxyTitle}_proxy_v602_10051')" >> /var/log/partition_10051.log
mysql -uroot -pxxxxxxxxx ${ProxyTitle}_proxy_v602_10053 -e "CALL partition_maintenance_all('${ProxyTitle}_proxy_v602_10053')" >> /var/log/partition_10053.log

sudo echo "" >> /etc/crontab
sudo echo "#partition for zabbix proxy v602" >> /etc/crontab
crontabinsert051="0 1 * * * root mysql -uroot -pxxxxxxxxx ${ProxyTitle}_proxy_v602_10051 -e \"CALL partition_maintenance_all('${ProxyTitle}_proxy_v602_10051')\" >> /var/log/partition_10051.log"
crontabinsert053="15 1 * * * root mysql -uroot -pxxxxxxxx ${ProxyTitle}_proxy_v602_10053 -e \"CALL partition_maintenance_all('${ProxyTitle}_proxy_v602_10053')\" >> /var/log/partition_10053.log"

#Prevent adding repetitive cronjobs during reinstallation (foolproof added 2024-11-26)
sudo sed -i '/0 1 \* \* \* root mysql -uroot -pxxxxxxxx.*-e "CALL partition_maintenance_all('\''.*_10051'\'')\" >> \/var\/log\/partition_10051.log/d' /etc/crontab
sudo sed -i '/15 1 \* \* \* root mysql -uroot -pxxxxxxxx.*-e "CALL partition_maintenance_all('\''.*_10053'\'')\" >> \/var\/log\/partition_10053.log/d' /etc/crontab

sudo echo "$crontabinsert051" >> /etc/crontab
sudo echo "$crontabinsert053" >> /etc/crontab
