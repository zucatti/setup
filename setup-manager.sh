#!/bin/bash

# ubuntu 16.04
#
# manager
# -------
# setup.sh
#
#

OMNEEDIA=/omneedia

[ -d "$OMNEEDIA" ] || mkdir -p $OMNEEDIA

if [ -z "$proxy" ]
then
	echo ""
else
	export http_proxy=$proxy
	export https_proxy=$proxy
	echo $proxy >> $OMNEEDIA/.proxy
fi

apt-get update
apt-get --assume-yes remove docker docker-engine docker.io containerd runc
apt-get --assume-yes install apt-transport-https ca-certificates curl git gnupg-agent software-properties-common nfs-common
curl -L https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
curl -L https://deb.nodesource.com/setup_10.x | sudo -E bash -
apt update
apt --assume-yes install docker-ce docker-ce-cli containerd.io nodejs

if [ -z "$proxy" ]
then
	echo ""
else
	git config --global http.proxy $proxy
	npm config set proxy $proxy

	mkdir -p /etc/systemd/system/docker.service.d
	touch /etc/systemd/system/docker.service.d/http-proxy.conf
	echo "[Service]" >> /etc/systemd/system/docker.service.d/http-proxy.conf
	echo "Environment=\"HTTP_PROXY=$proxy/\"" >> /etc/systemd/system/docker.service.d/http-proxy.conf
	echo "Environment=\"HTTPS_PROXY=$proxy\"" >> /etc/systemd/system/docker.service.d/http-proxy.conf
	echo "Environment=\"NO_PROXY=localhost,127.0.0.1,.cerema.fr\"" >> /etc/systemd/system/docker.service.d/http-proxy.conf

	systemctl daemon-reload
	systemctl restart docker
fi

curl -o /usr/bin/docker-volume-netshare https://github.com/ContainX/docker-volume-netshare/releases/download/v0.35/docker-volume-netshare_0.35_linux_amd64-bin
chmod +x /usr/bin/docker-volume-netshare

echo "[Unit]" > /etc/systemd/system/docker-volume-netshare.service
echo "Description=Docker NFS, AWS EFS & Samba/CIFS Volume Plugin" >> /etc/systemd/system/docker-volume-netshare.service
echo "Documentation=https://github.com/gondor/docker-volume-netshare" >> /etc/systemd/system/docker-volume-netshare.service
echo "Wants=network-online.target" >> /etc/systemd/system/docker-volume-netshare.service
echo "After=network-online.target" >> /etc/systemd/system/docker-volume-netshare.service
echo "Before=docker.service" >> /etc/systemd/system/docker-volume-netshare.service
echo " " >> /etc/systemd/system/docker-volume-netshare.service
echo "[Service]" >> /etc/systemd/system/docker-volume-netshare.service
echo "ExecStart=/usr/bin/docker-volume-netshare nfs" >> /etc/systemd/system/docker-volume-netshare.service
echo "StandardOutput=syslog" >> /etc/systemd/system/docker-volume-netshare.service
echo " " >> /etc/systemd/system/docker-volume-netshare.service
echo "[Install]" >> /etc/systemd/system/docker-volume-netshare.service
echo "WantedBy=multi-user.target" >> /etc/systemd/system/docker-volume-netshare.service

systemctl enable docker-volume-netshare.service
systemctl start docker-volume-netshare.service

OMNEEDIA_MANAGER=$OMNEEDIA/manager
[ -d "$OMNEEDIA_MANAGER" ] || mkdir -p $OMNEEDIA_MANAGER
cat /dev/zero | ssh-keygen -q -N "" > /dev/null
git clone https://github.com/omneedia/tpl.omneedia.web $OMNEEDIA_MANAGER/web

# volume server
apt-get install -y nfs-kernel-server
git clone https://gitlab.com/omneedia/install-manager $OMNEEDIA/setup
cd $OMNEEDIA/setup
npm install
cd cert
npm install
cd ..
node deploy

echo "Installation done."