#!/bin/bash
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
local_ip=$(hostname -I | awk '{print $1}')

echo -e "${GREEN}<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>"
echo -e "${GREEN}==============================================="
echo -e "${GREEN}   Apakah anda benar-benar sudah MAKAN? (y/n)${NC}"
echo -e "${GREEN}==============================================="
echo -e "${GREEN}<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>"
read confirmation

if [ "$confirmation" != "y" ]; then
    echo -e "${GREEN}Install dibatalkan. Tolong MAKAN dulu ya.${NC}"
    /tmp/install.sh
    exit 1
fi
for ((i = 5; i >= 1; i--)); do
	sleep 1
    echo "Nungguin ya. Sabar dong..."
done

#MongoDB
if ! sudo systemctl is-active --quiet mongod; then
    curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
	echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list

	sudo apt update
	sudo apt install mongodb-org -y
	sudo systemctl start mongod.service
	sudo systemctl enable mongod
else
	echo -e "${GREEN}<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>"
	echo -e "${GREEN}==============================================="
    echo -e "${GREEN}     Mongodb sudah terinstall sebelumnya. ${NC}"
	echo -e "${GREEN}==============================================="
	echo -e "${GREEN}<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>"
fi
sleep 3
if ! sudo systemctl is-active --quiet mongod; then
    sudo rm TR069_server/install.sh
    exit 1
fi

#NodeJS Install
check_node_version() {
    if command -v node > /dev/null 2>&1; then
        NODE_VERSION=$(node -v | cut -d 'v' -f 2)
        NODE_MAJOR_VERSION=$(echo $NODE_VERSION | cut -d '.' -f 1)
        NODE_MINOR_VERSION=$(echo $NODE_VERSION | cut -d '.' -f 2)

        if [ "$NODE_MAJOR_VERSION" -lt 12 ] || { [ "$NODE_MAJOR_VERSION" -eq 12 ] && [ "$NODE_MINOR_VERSION" -lt 13 ]; } || [ "$NODE_MAJOR_VERSION" -gt 22 ]; then
            return 1
        else
            return 0
        fi
    else
        return 1
    fi
}

if ! check_node_version; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - \
	
	sudo apt update
	sudo apt-get install -y nodejs
	npm install -g npm@11.1.0
	sudo apt install unzip
	
else
    NODE_VERSION=$(node -v | cut -d 'v' -f 2)
    echo -e "${GREEN}NodeJS sudah terinstall versi ${NODE_VERSION}. ${NC}"

fi
if ! check_node_version; then
    sudo rm TR069_server/install.sh
    exit 1
fi

#GenieACS
if !  systemctl is-active --quiet genieacs-{cwmp,fs,ui,nbi}; then
	echo -e "${GREEN}<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>"
	echo -e "${GREEN}==============================================="
    echo -e "${GREEN}    Menginstall genieACS CWMP, FS, NBI, UI ${NC}"
	echo -e "${GREEN}==============================================="
	echo -e "${GREEN}<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>"
	
	npm install -g genieacs@1.2.13
    useradd --system --no-create-home --user-group genieacs || true
    mkdir -p /opt/genieacs
    mkdir -p /opt/genieacs/ext
    chown genieacs:genieacs /opt/genieacs/ext
    cat << EOF > /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
GENIEACS_EXT_DIR=/opt/genieacs/ext
GENIEACS_UI_JWT_SECRET=secret
EOF
    chown genieacs:genieacs /opt/genieacs/genieacs.env
    chown genieacs. /opt/genieacs -R
    chmod 600 /opt/genieacs/genieacs.env
    mkdir -p /var/log/genieacs
    chown genieacs. /var/log/genieacs
    # create systemd unit files
## CWMP
    cat << EOF > /etc/systemd/system/genieacs-cwmp.service
[Unit]
Description=GenieACS CWMP
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-cwmp

[Install]
WantedBy=default.target
EOF

## NBI
    cat << EOF > /etc/systemd/system/genieacs-nbi.service
[Unit]
Description=GenieACS NBI
After=network.target
 
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-nbi
 
[Install]
WantedBy=default.target
EOF

## FS
    cat << EOF > /etc/systemd/system/genieacs-fs.service
[Unit]
Description=GenieACS FS
After=network.target
 
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-fs
 
[Install]
WantedBy=default.target
EOF

## UI
    cat << EOF > /etc/systemd/system/genieacs-ui.service
[Unit]
Description=GenieACS UI
After=network.target
 
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-ui
 
[Install]
WantedBy=default.target
EOF

# config logrotate
 cat << EOF > /etc/logrotate.d/genieacs
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
}
EOF
    echo -e "${GREEN}<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>"
	echo -e "${GREEN}==============================================="
	echo -e "${GREEN}       Install APP GenieACS selesai...    ${NC}"
    echo -e "${GREEN}==============================================="
	echo -e "${GREEN}<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>"
	
	systemctl daemon-reload
    systemctl enable --now genieacs-{cwmp,fs,ui,nbi}
    systemctl start genieacs-{cwmp,fs,ui,nbi}
	
	echo -e "${GREEN}<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>"
	echo -e "${GREEN}==============================================="
    echo -e "${GREEN}       Sukses genieACS CWMP, FS, NBI, UI  ${NC}"
	echo -e "${GREEN}==============================================="
	echo -e "${GREEN}<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>"
else
    echo -e "${RED}<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>"
	echo -e "${RED}==============================================="
	echo -e "${RED}     GenieACS sudah terinstall sebelumnya.${NC}"
	echo -e "${RED}==============================================="
	echo -e "${RED}<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>"
fi

#Sukses
	echo -e "${GREEN}<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>"
	echo -e "${GREEN}==============================================="
	echo -e "${GREEN}          Sekarang install parameter.          "
	echo -e "${GREEN}      Apakah anda ingin melanjutkan? (y/n)${NC}"
	echo -e "${GREEN}==============================================="
	echo -e "${GREEN}<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>"
	read confirmation

if [ "$confirmation" != "y" ]; then
	echo -e "${RED}<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>"
	echo -e "${RED}==============================================="
    echo -e "${RED}           Install dibatalkan..           ${NC}"
	echo -e "${RED}==============================================="
	echo -e "${RED}<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>"
    exit 1
fi
for ((i = 5; i >= 1; i--)); do
	sleep 1
    echo "Nungguin ya. Sabar dong"
done

	rm -r /usr/lib/node_modules/genieacs
	unzip genieacs.zip -d /usr/lib/node_modules/

	sudo mongodump --db=genieacs --out genieacs-backup
	sudo mongorestore --db=genieacs --drop virtualparameter

#Sukses
	echo -e "${GREEN}<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	echo -e "${GREEN}====================================================="
	echo -e "${GREEN}       Akses GenieACS : http://$local_ip:3000   ${NC}"
	echo -e "${GREEN}====================================================="
	echo -e "${GREEN}<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>"

	sudo chmod -R 755 /usr/lib/node_modules/genieacs/bin/genieacs-{cwmp,ext,fs,ui,nbi}
	sudo ufw allow 3000
	sudo ufw allow 7547