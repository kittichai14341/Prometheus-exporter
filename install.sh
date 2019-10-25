#!/bin/bash
while getopts ":U:P:h:p::d::" options; do
    case "${options}" in
        U) Username=${OPTARG} ;;
        P) Password=${OPTARG} ;;
        h) Host=${OPTARG} ;;
        p) Port=${OPTARG} ;;
        d) Database=${OPTARG} ;;
        *) echo "Invalid option: -${options}" ;;
    esac
done

if [ "${Host}" = "" ] ; then Host=127.0.0.1 ; fi

if [ "${Port}" = "" ] ; then Port=3306 ; fi

if [ "${Database}" = "" ] ; then Database=information_schema ; fi

echo "Username = ${Username}"
echo "Password = ${Password}"
echo "Host = ${Host}"
echo "Port = ${Port}"
echo "Database = ${Database}"

if [ `id -u` -ne 0 ] ; then echo "Please run as root" ; exit 1 ; fi

if [ -x "$(command -v apt-get)" ]; then 
    if ! dpkg -l | grep -qw unzip ; then
    apt-get install unzip
    fi
fi

if [ -x "$(command -v yum)" ]; then 
    if ! rpm -qa | grep -qw unzip ; then
        yum install unzip
    fi
fi

wget https://github.com/kittichai14341/Prometheus-exporter/raw/master/prometheus-exporter.zip -O /tmp/prometheus-exporter.zip

if [ ! -e /tmp/prometheus-exporter.zip ] ; then 
    echo "Fail to download prometheus-exporter.zip"
    exit 1 ; 
fi

cd /tmp/

unzip prometheus-exporter.zip

chmod 0777 /tmp/node_exporter /tmp/mysqld_exporter

sudo mv /tmp/node_exporter /usr/local/bin/
sudo mv /tmp/mysqld_exporter /usr/local/bin/

if [ ! -e /usr/local/bin/node_exporter ] ; then echo "Fail to move node_exporter" ; exit 1 ; fi
if [ ! -e /usr/local/bin/mysqld_exporter ] ; then echo "Fail to move mysqld_exporter" ; exit 1 ; fi

echo "[Unit]
Description=Node Exporter
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/node_exporter
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/node_exporter.service

echo "[Unit]
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

sudo systemctl daemon-reload
sudo systemctl start node_exporter mysqld_exporter
sudo systemctl status node_exporter mysqld_exporter
sudo systemctl enable node_exporter mysqld_exporter