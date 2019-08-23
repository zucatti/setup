#!/bin/bash

#
# Omneedia Server
#


SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
TZ=Europe/Paris
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
DEBIAN_FRONTEND=noninteractive

while getopts p:t:d:a:v:s:k:m: option
do
case "${option}"
in
p) PROXY=${OPTARG};;
t) TYPE=${OPTARG};;
d) DIR=${OPTARG};;
a) ADDR=${OPTARG};;
v) VOLUME=${OPTARG};;
s) STORE=${OPTARG};;
k) VOLKEY=${OPTARG};;
m) MY_MANAGER=${OPTARG};;
esac
done

if [ -z "$STORE" ]
then
    STORE="/mnt"
fi

if ! [ -z "$PROXY" ]
then
	export http_proxy=$PROXY
	export https_proxy=$PROXY
    echo use_proxy=yes
    echo http_proxy=$PROXY >> ~/.wgetrc
    echo https_proxy=$PROXY >> ~/.wgetrc
fi

if [ "$TYPE" == "worker" ]; then
    if [ -z "$MY_MANAGER" ]; then
        echo "You must provide a manager IP"
        exit 1;
    fi
fi

if [ "$TYPE" == "manager" ]; then
    INSTALL_VOLUME=1
    if ! [ -z "$VOLUME" ]
    then
        INSTALL_VOLUME=0
        if [ -z "$VOLKEY" ]
        then
            echo "You must provide a valid volumemanager auth token"
            exit 1;
        fi
    fi
else
    INSTALL_VOLUME=0
fi

if [ "$TYPE" == "volume" ]; then
    INSTALL_VOLUME=1
fi

apt-get update
bash -c "$(wget -O - https://deb.nodesource.com/setup_10.x)"
apt update
apt-get --assume-yes install glances nodejs apt-transport-https ca-certificates curl git gnupg-agent software-properties-common nfs-common

if ! [ -z "$PROXY" ]
then
	git config --global http.proxy $PROXY
	npm config set proxy $PROXY
    if [ -z "$ADDR" ]
    then
        echo "You must provide an adress IP"
        exit 1;
    fi
else
    PUBLIC_IP=`wget http://ipecho.net/plain -O - -q ; echo`
fi

if [ -z "$ADDR" ] 
then
    ADDR=$PUBLIC_IP
fi

if [ "$INSTALL_VOLUME" == 1 ]; then
    export DIR_STORE=$STORE
    mkdir -p $DIR_STORE/bin
    git clone https://oauth2:$KEY@gitlab.com/omneedia/volume-service $DIR_STORE/bin/volumemanager
    cd $DIR_STORE/bin/volumemanager/bin
    npm install
    cd $SCRIPTPATH
    echo "[Unit]" >> /etc/systemd/system/omneedia-volume.service
    echo "Description=Volume service for omneedia" >> /etc/systemd/system/omneedia-volume.service
    echo "Documentation=https://docs.omneedia.com" >> /etc/systemd/system/omneedia-volume.service
    echo "After=network.target" >> /etc/systemd/system/omneedia-volume.service
    echo " " >> /etc/systemd/system/omneedia-volume.service
    echo "[Service]" >> /etc/systemd/system/omneedia-volume.service
    echo "Environment=NODE_PORT=33777" >> /etc/systemd/system/omneedia-volume.service
    echo "Type=simple" >> /etc/systemd/system/omneedia-volume.service
    echo "User=root" >> /etc/systemd/system/omneedia-volume.service
    echo "ExecStart=/usr/bin/node $DIR_STORE/bin/volumemanager/bin/volumemanager.js" >> /etc/systemd/system/omneedia-volume.service
    echo "Restart=on-failure" >> /etc/systemd/system/omneedia-volume.service
    echo " " >> /etc/systemd/system/docker-volume.service
    echo "[Install]" >> /etc/systemd/system/omneedia-volume.service
    echo "WantedBy=multi-user.target" >> /etc/systemd/system/omneedia-volume.service

    systemctl enable omneedia-volume.service
    systemctl start omneedia-volume.service

    apt-get install -y nfs-kernel-server
    mkdir -p /mnt
    systemctl restart nfs-kernel-server

    echo "$STORE 127.0.0.1(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    echo "$STORE $ADDR(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    exportfs -ra    
    VOLKEY=$(cat $DIR_STORE/bin/volumemanager/config/key)
    echo "Please note the volumeservice token: $VOLKEY"
    
    if [ "$TYPE" == "volume" ]; then
        echo "DIR_STORE=$STORE" >> /etc/environment
        export DIR_STORE=$STORE
        exit 1;
    fi
fi

apt-get --assume-yes remove docker docker-engine docker.io containerd runc 
wget -qO - https://download.docker.com/linux/ubuntu/gpg | apt-key add -

add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-add-repository -y ppa:ansible/ansible
apt update
apt --assume-yes install docker-ce docker-ce-cli containerd.io

if ! [ -z "$PROXY" ]
then
	mkdir -p /etc/systemd/system/docker.service.d
	touch /etc/systemd/system/docker.service.d/http-proxy.conf
	echo "[Service]" >> /etc/systemd/system/docker.service.d/http-proxy.conf
	echo "Environment=\"HTTP_PROXY=$PROXY/\"" >> /etc/systemd/system/docker.service.d/http-proxy.conf
	echo "Environment=\"HTTPS_PROXY=$PROXY\"" >> /etc/systemd/system/docker.service.d/http-proxy.conf
	echo "Environment=\"NO_PROXY=localhost,127.0.0.1,.cerema.fr\"" >> /etc/systemd/system/docker.service.d/http-proxy.conf

	systemctl daemon-reload
	systemctl restart docker
fi

wget -O /usr/bin/docker-volume-netshare https://github.com/ContainX/docker-volume-netshare/releases/download/v0.35/docker-volume-netshare_0.35_linux_amd64-bin
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

if [ "$TYPE" == "worker" ]; then
    bash -c "$(wget -O - http://$MY_MANAGER:33333/add/$ADDR)"
    exit 1;
else
    UCF_FORCE_CONFOLD=1 DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -qq -y --assume-yes install ansible
fi

if [ "$TYPE" == "manager" ]; then
	cat /dev/zero | ssh-keygen -q -N "" > /dev/null
    docker swarm init --advertise-addr $ADDR:2377
    docker network create public -d overlay
    TOKEN="`docker swarm join-token manager -q`"
    TOKEN_WORKER="`docker swarm join-token worker -q`"
    MANAGER_ID="`docker node ls -f "role=manager" | awk 'FNR == 2 {print $1}'`"
    if ! [ -z "$VOLUME" ]
    then
        wget -O - --header="Authorization: Bearer $VOLKEY" --post-data="ip=$ADDR" http://$VOLUME:33777/auth
        echo "$VOLUME:$STORE    $STORE    nfs    defaults    0 0 " >> /etc/fstab
        mount -a
        echo "DATASTORE=$VOLUME" >> /etc/environment
        export DATASTORE=$VOLUME
    else
        echo "DATASTORE=$ADDR" >> /etc/environment 
        export DATASTORE=$ADDR
    fi
    
    echo "{\"id\":\"$MANAGER_ID\",\"store\":\"$DATASTORE\",\"dir\":\"$STORE\",\"volume-token\":\"$VOLKEY\",\"token\":\"$TOKEN\",\"worker\":\"$TOKEN_WORKER\"}" > $DIR_STORE/.env
    
    echo "MANAGER_ID=$MANAGER_ID" >> /etc/environment
    echo "VOLUME_TOKEN=$VOLKEY" >> /etc/environment
    echo "MANAGER_TOKEN=$TOKEN" >> /etc/environment
    echo "WORKER_TOKEN=$TOKEN_WORKER" >> /etc/environment
    echo "DIR_STORE=$STORE" >> /etc/environment

    echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
    echo "UserKnownHostsFile=/dev/null" >> /etc/ssh/ssh_config

    export MANAGER_ID=$MANAGER_ID
    export VOLUME_TOKEN=$VOLKEY
    export MANAGER_TOKEN=$TOKEN
    export WORKER_TOKEN=$TOKEN_WORKER
    git clone https://oauth2:$KEY@gitlab.com/omneedia/start /tmp/start
    mv /tmp/start/certs /mnt/certs
    mv /tmp/start/config /mnt/config
    mv /tmp/start/data /mnt/data
    mv /tmp/start/logs /mnt/logs
    mv /tmp/start/stacks /mnt/stacks
    docker stack deploy --compose-file /mnt/stacks/omneedia-web.yml omneedia-web
fi
