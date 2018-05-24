#!/bin/bash

function install_minio () {
    if ! getent passwd minio 2>&1 > /dev/null; then
	    echo "creating minio user..."
	    useradd -d /home/minio -m -s /bin/false minio
	    echo "... DONE!"
    fi
    if [ ! -d /data ]; then
	    echo "creating minio storage..."
	    mkdir /data && chown minio:minio /data && chmod 755 /data
	    echo "... DONE!"
    fi
    if [ ! -f /usr/local/bin/minio ]; then
        echo "downloading minio..."
        curl -LsO https://dl.minio.io/server/minio/release/linux-amd64/minio \
        && mv minio /usr/local/bin \
        && chmod 755 /usr/local/bin/minio
        echo "... DONE!"
    fi
}

function configure_service () {
    if ! systemctl is-enabled minio 2>&1 > /dev/null; then
	    echo "installing minio daemon..."
        cat > /etc/systemd/system/minio.service <<EOFMINIOSERVICE
[Unit]
Description=Minio Storage Daemon
Wants=network.target
After=syslog.target
After=network.target

[Service]
User=minio
RestartSec=10s
Restart=always
Type=simple
ExecStart=/usr/local/bin/minio server --address :9001 /data

[Install]
WantedBy=default.target
Alias=minio.service
EOFMINIOSERVICE
	    chown root:root /etc/systemd/system/minio.service
        chmod 664 /etc/systemd/system/minio.service
	    systemctl daemon-reload
	    systemctl list-units minio.service --all
	    systemctl enable minio.service
	    echo "... DONE!"
    fi
    if ! systemctl is-active minio 2>&1 > /dev/null; then
	    echo "starting minio daemon..."
	    systemctl start minio.service
	    echo $?
	    echo "... DONE!"
    fi
}

install_minio
configure_service
