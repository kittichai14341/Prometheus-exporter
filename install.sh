#!/bin/bash
while getopts ":U:P:h:p::d::I:" options; do
    case "${options}" in
        U) Username=${OPTARG} ;;
        P) Password=${OPTARG} ;;
        h) Host=${OPTARG} ;;
        p) Port=${OPTARG} ;;
        d) Database=${OPTARG} ;;
        I) Ipdocker=${OPTARG} ;;
        *) echo "Invalid option: -$opt" ;;
    esac
done

if [ "${Port}" = "" ] ; then Port=3306 ; fi

if [ "${Database}" = "" ] ; then Database=information_schema ; fi

echo "Username = ${Username}"
echo "Password = ${Password}"
echo "Host = ${Host}"
echo "Port = ${Port}"
echo "Database = ${Database}"
echo "Ipdocker = ${Ipdocker}"

if [ `id -u` -ne 0 ] ; then echo "Please run as root" ; exit 1 ; fi

if [ -x "$(command -v apt-get)" ]; then apt-get -y install unzip jq ; fi

if [ -x "$(command -v yum)" ]; then sudo yum -y install unzip xinetd redhat-lsb-core nmap jq ; fi

wget https://github.com/kittichai14341/Prometheus-exporter/raw/master/prometheus-exporter.zip -O /tmp/prometheus-exporter.zip

if [[ ! -e /tmp/prometheus-exporter.zip ]] ; then echo "Fail to download prometheus-exporter.zip" ; exit 1 ; fi

cd /tmp/

unzip prometheus-exporter.zip
mkdir -p /opt/metrics.d/

chmod 0777 /tmp/node_exporter /tmp/mysqld_exporter

sudo mv /tmp/node_exporter /usr/local/bin/
sudo mv /tmp/mysqld_exporter /usr/local/bin/
sudo mv /tmp/loadscript /opt/metrics.d/loadscript
sudo mv /tmp/httpwrapper /opt/metrics.d/httpwrapper 

chmod +x /opt/metrics.d/*

if [[ ! -e /usr/local/bin/node_exporter ]] ; then echo "Fail to move node_exporter" ; exit 1 ; fi
if [[ ! -e /usr/local/bin/mysqld_exporter ]] ; then echo "Fail to move mysqld_exporter" ; exit 1 ; fi

sudo useradd -rs /bin/false node_exporter
sudo useradd mysqld_exporter

if [[ `compgen -u node_exporter` != "node_exporter" ]] ; then echo "Fail to add user [node_exporter]" ; exit 1 ; fi
if [[ `compgen -u mysqld_exporter` != "mysqld_exporter" ]] ; then echo "Fail to add user [mysqld_exporter]" ; exit 1 ; fi

echo "
[Unit]
Description=Node Exporter
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/node_exporter
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/node_exporter.service

echo "
[Unit]
Description=MySQL Exporter Service
Wants=network.target
After=network.target
[Service]
Environment=\"DATA_SOURCE_NAME=${Username}:${Password}@(${Host}:${Port})/${Database}\"
Type=simple
ExecStart=/usr/local/bin/mysqld_exporter
Restart=always
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/mysqld_exporter.service

echo "
service loadscript
{
  type = unlisted
  port = 9200
  socket_type = stream
  wait = no
  user = root
  server = /opt/metrics.d/httpwrapper
  server_args = loadscript
  disable = no
  only_from = ${Ipdocker}
  log_type = FILE /dev/null
}" > /etc/xinetd.d/xinetd-service-file

if [ -x "$(command -v apt-get)" ]; then /etc/init.d/xinetd restart ; fi

if [ -x "$(command -v yum)" ]; then sudo service xinetd restart ; fi

sudo systemctl daemon-reload
sudo systemctl restart node_exporter mysqld_exporter xinetd
sudo systemctl status node_exporter mysqld_exporter xinetd
sudo systemctl enable node_exporter mysqld_exporter