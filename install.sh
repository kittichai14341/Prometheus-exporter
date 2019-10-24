#!/bin/bash
while getopts ":U:P:h:p:d::" options; do
    case "${options}" in
        U) Username=${OPTARG} ;;
        P) Password=${OPTARG} ;;
        h) Host=${OPTARG} ;;
        p) Port=${OPTARG} ;;
        d) Database=${OPTARG} ;;
        *) echo "Invalid option: -$opt" ;;
    esac
done

echo "Username = ${Username}"
echo "Password = ${Password}"
echo "Host = ${Host}"
echo "Port = ${Port}"
echo "Database = ${Database}"

if [[ `id -u` -ne 0 ]] ; then echo "Please run as root" ; exit 1 ; fi

if [ -x "$(command -v apt-get)" ]; then apt-get install install zip unzip; fi

if [ -x "$(command -v yum)" ]; then sudo yum install zip unzip ; fi

wget http://monitor.ithesis.co:8000/prometheus-exporter.zip -O /tmp/prometheus-exporter.zip

if [[ ! -e /tmp/prometheus-exporter.zip ]] ; then echo "Fail to download prometheus-exporter.zip" ; exit 1 ; fi

cd /tmp/

unzip prometheus-exporter.zip

sudo mv /tmp/node_exporter /usr/local/bin/
sudo mv /tmp/mysqld_exporter /usr/local/bin/

if [[ ! -e /usr/local/bin/node_exporter ]] ; then echo "Fail to move node_exporter" ; exit 1 ; fi
if [[ ! -e /usr/local/bin/mysqld_exporter ]] ; then echo "Fail to move node_exporter" ; exit 1 ; fi

# sudo useradd -rs /bin/false node_exporter
# sudo useradd mysqld_exporter

# if [[ `compgen -u node_exporter` != "node_exporter" ]] ; then echo "Fail to add user [node_exporter]" ; exit 1 ; fi
# if [[ `compgen -u mysqld_exporter` != "mysqld_exporter" ]] ; then echo "Fail to add user [mysqld_exporter]" ; exit 1 ; fi

echo "
[Unit]
Description=Node Exporter
After=network.target
[Service]
User=node_exporter
Group=node_exporter
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
User=mysqld_exporter
Group=mysqld_exporter
Environment=\"DATA_SOURCE_NAME=${Username}:${Password}@(${Host}:${Port})/${Database}\"
Type=simple
ExecStart=/usr/bin/mysqld_exporter
Restart=always
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/mysqld_exporter.service

sudo systemctl daemon-reload
sudo systemctl start node_exporter mysqld_exporter
sudo systemctl status node_exporter mysqld_exporter
sudo systemctl enable node_exporter mysqld_exporter