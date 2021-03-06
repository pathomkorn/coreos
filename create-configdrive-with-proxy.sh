#!/bin/bash

## [2017-02-27 PM] Forked from https://raw.github.com/coreos/scripts/master/contrib/create-basic-configdrive
## [2017-02-27 PM] Added network parameters by pathomkorn

DEFAULT_ETCD_DISCOVERY="https://discovery.etcd.io/TOKEN"
DEFAULT_ETCD_ADDR="http://ETCD_NETWORK_IPADDR:2379"
DEFAULT_ETCD_PEER_URLS="http://ETCD_NETWORK_IPADDR:2380"
DEFAULT_ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
DEFAULT_ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379,http://0.0.0.0:4001"

USAGE="Usage: $0 -H HOSTNAME -S SSH_FILE -1 INTERFACE -2 IPADDR -3 PREFIX -4 GATEWAY -5 DNSSERVER -6 PROXYSERVER -7 NTPSERVER [-p /target/path] [-d|-e|-i|-n|-t|-h]
Options:
    -1 INTERFACE       Network interface name.
    -2 IPADDR          Network IP address.
    -3 PREFIX          Network IP prefix.
    -4 GATEWAY         Network gateway.
    -5 DNSSERVER       Network DNS server.
    -6 PROXYSERVER     Internet proxy server.
    -7 NTPSERVER       Internet proxy server.
    -d URL             Full URL path to discovery endpoint.
    -e http://IP:PORT  Adviertise URL for client communication.
    -H HOSTNAME        Machine hostname.
    -i http://IP:PORT  URL for server communication.
    -l http://IP:PORT  Listen URL for client communication.
    -u http://IP:PORT  Listen URL for server communication.
    -n NAME            etcd node name.
    -p DEST            Create config-drive ISO image to the given path.
    -S FILE            SSH keys file.
    -t TOKEN           Token ID from https://discovery.etcd.io.
    -h                 This help

This tool creates a basic config-drive ISO image.
"

CLOUD_CONFIG="#cloud-config

coreos:
  etcd2:
    name: <ETCD_NAME>
    advertise-client-urls: <ETCD_ADDR>
    initial-advertise-peer-urls: <ETCD_PEER_URLS>
    discovery: <ETCD_DISCOVERY>
    discovery-proxy: <ETCD_PROXYSERVER>
    listen-peer-urls: <ETCD_LISTEN_PEER_URLS>
    listen-client-urls: <ETCD_LISTEN_CLIENT_URLS>
  units:
    - name: etcd2.service
      command: start
    - name: fleet.service
      command: start
    - name: docker-tcp.socket
      command: start
      enable: true
      content: |
        [Unit]
        Description=Docker Socket for the API

        [Socket]
        ListenStream=2375
        Service=docker.service
        BindIPv6Only=both

        [Install]
        WantedBy=sockets.target
    - name: docker.service
      drop-ins:
        - name: 20-http-proxy.conf
          content: |
            [Service]
            Environment='HTTP_PROXY=<ETCD_PROXYSERVER>'
        - name: 30-increase-ulimit.conf
          content: |
            [Service]
            LimitMEMLOCK=infinity
      command: restart
    - name: 00-<ETCD_NETWORK_INTERFACE>.network
      runtime: true
      content: |
        [Match]
        Name=<ETCD_NETWORK_INTERFACE>

        [Network]
        Address=<ETCD_NETWORK_IPADDR>/<ETCD_NETWORK_PREFIX>
        Gateway=<ETCD_NETWORK_GATEWAY>
        DNS=<ETCD_NETWORK_DNSSERVER>
        NTP=<ETCD_NTPSERVER>
ssh_authorized_keys:
  - <SSH_KEY>
hostname: <HOSTNAME>
"
REGEX_SSH_FILE="^ssh-(rsa|dss|ed25519) [-A-Za-z0-9+\/]+[=]{0,2} .+"

while getopts "1:2:3:4:5:6:7:d:e:H:i:n:p:S:t:l:u:h" OPTION
do
    case $OPTION in
        1) ETCD_NETWORK_INTERFACE="$OPTARG" ;;
        2) ETCD_NETWORK_IPADDR="$OPTARG" ;;
        3) ETCD_NETWORK_PREFIX="$OPTARG" ;;
        4) ETCD_NETWORK_GATEWAY="$OPTARG" ;;
        5) ETCD_NETWORK_DNSSERVER="$OPTARG" ;;
        6) ETCD_PROXYSERVER="$OPTARG" ;;
        7) ETCD_NTPSERVER="$OPTARG" ;;
        d) ETCD_DISCOVERY="$OPTARG" ;;
        e) ETCD_ADDR="$OPTARG" ;;
        H) HNAME="$OPTARG" ;;
        i) ETCD_PEER_URLS="$OPTARG" ;;
        n) ETCD_NAME="$OPTARG" ;;
        p) DEST="$OPTARG" ;;
        S) SSH_FILE="$OPTARG" ;;
        t) TOKEN="$OPTARG" ;;
        u) ETCD_LISTEN_PEER_URLS="$OPTARG" ;;
        l) ETCD_LISTEN_CLIENT_URLS="$OPTARG" ;;
        h) echo "$USAGE"; exit;;
        *) exit 1;;
    esac
done

# root user forbidden
if [ $(id -u) -eq 0 ]; then
    echo "$0: This script should not be run as root." >&2
    exit 1
fi

# mkisofs/genisoimage tool check
if which mkisofs &>/dev/null; then
    mkisofs=$(which mkisofs)
elif which genisoimage &>/dev/null; then
    mkisofs=$(which genisoimage)
else 
    echo "$0: mkisofs or genisoimage tool is required to create image." >&2
    exit 1
fi

if [ -z "$HNAME" ]; then
    echo "$0: The hostname parameter '-H' is required." >&2
    exit 1
fi

if [ -z "$SSH_FILE" ]; then
    echo "$0: The SSH filename parameter '-S' is required." >&2
    exit 1
fi

if [[ ! -r "$SSH_FILE" ]]; then
    echo "$0: The SSH file (${SSH_FILE}) was not found." >&2
    exit 1
fi

if [ $(cat "$SSH_FILE" | wc -l) -eq 0 ]; then
    echo "$0: The SSH file (${SSH_FILE}) is empty." >&2
    exit 1
fi

if [ $(grep -v -E "$REGEX_SSH_FILE" "$SSH_FILE" | wc -l) -gt 0 ]; then
    echo "$0: The SSH file (${SSH_FILE}) content is invalid." >&2
    exit 1
fi

if [ -z "$ETCD_NETWORK_INTERFACE" ]; then
    echo "$0: The network interface name parameter '-1' is required." >&2
    exit 1
fi

if [ -z "$ETCD_NETWORK_IPADDR" ]; then
    echo "$0: The network IP address parameter '-2' is required." >&2
    exit 1
fi

if [ -z "$ETCD_NETWORK_PREFIX" ]; then
    echo "$0: The network IP prefix parameter '-3' is required." >&2
    exit 1
fi

if [ -z "$ETCD_NETWORK_GATEWAY" ]; then
    echo "$0: The network gateway parameter '-4' is required." >&2
    exit 1
fi

if [ -z "$ETCD_NETWORK_DNSSERVER" ]; then
    echo "$0: The network DNS server parameter '-5' is required." >&2
    exit 1
fi

if [ -z "$ETCD_PROXYSERVER" ]; then
    echo "$0: The Internet proxy server parameter '-6' is required." >&2
    exit 1
fi

if [ -z "$ETCD_NTPSERVER" ]; then
    echo "$0: The NTP server parameter '-7' is required." >&2
    exit 1
fi

if [ -z "$DEST" ]; then
    DEST=$PWD
fi

if [[ ! -d "$DEST" ]]; then
    echo "$0: Target path (${DEST}) do not exists." >&2
    exit 1
fi

if [ ! -z "$ETCD_DISCOVERY" ] && [ ! -z "$TOKEN" ]; then
    echo "$0: You cannot specify both discovery token and discovery URL." >&2
    exit 1
fi

if [ ! -z "$TOKEN" ]; then
    ETCD_DISCOVERY="${DEFAULT_ETCD_DISCOVERY//TOKEN/$TOKEN}"
fi

if [ -z "$ETCD_DISCOVERY" ]; then
    ETCD_DISCOVERY=$DEFAULT_ETCD_DISCOVERY
fi

if [ -z "$ETCD_NAME" ]; then
    ETCD_NAME=$HNAME
fi

if [ -z "$ETCD_ADDR" ]; then
    ETCD_ADDR="${DEFAULT_ETCD_ADDR//ETCD_NETWORK_IPADDR/$ETCD_NETWORK_IPADDR}"
fi

if [ -z "$ETCD_PEER_URLS" ]; then
    ETCD_PEER_URLS="${DEFAULT_ETCD_PEER_URLS//ETCD_NETWORK_IPADDR/$ETCD_NETWORK_IPADDR}"
fi

if [ -z "$ETCD_LISTEN_PEER_URLS" ]; then
    ETCD_LISTEN_PEER_URLS=$DEFAULT_ETCD_LISTEN_PEER_URLS
fi

if [ -z "$ETCD_LISTEN_CLIENT_URLS" ]; then
    ETCD_LISTEN_CLIENT_URLS=$DEFAULT_ETCD_LISTEN_CLIENT_URLS
fi

WORKDIR="${DEST}/tmp.${RANDOM}"
mkdir "$WORKDIR"
trap "rm -rf '${WORKDIR}'" EXIT

CONFIG_DIR="${WORKDIR}/openstack/latest"
CONFIG_FILE="${CONFIG_DIR}/user_data"
CONFIGDRIVE_FILE="${DEST}/${HNAME}-proxy.iso"

mkdir -p "$CONFIG_DIR"

while read l; do
    if [ -z "$SSH_KEY" ]; then
        SSH_KEY="$l"
    else
        SSH_KEY="$SSH_KEY
  - $l"
    fi
done < "$SSH_FILE"

CLOUD_CONFIG="${CLOUD_CONFIG/<ETCD_NAME>/${ETCD_NAME}}"
CLOUD_CONFIG="${CLOUD_CONFIG/<ETCD_DISCOVERY>/${ETCD_DISCOVERY}}"
CLOUD_CONFIG="${CLOUD_CONFIG/<ETCD_PROXYSERVER>/${ETCD_PROXYSERVER}}"
CLOUD_CONFIG="${CLOUD_CONFIG/<ETCD_PROXYSERVER>/${ETCD_PROXYSERVER}}"
CLOUD_CONFIG="${CLOUD_CONFIG/<ETCD_ADDR>/${ETCD_ADDR}}"
CLOUD_CONFIG="${CLOUD_CONFIG/<ETCD_PEER_URLS>/${ETCD_PEER_URLS}}"
CLOUD_CONFIG="${CLOUD_CONFIG/<ETCD_LISTEN_PEER_URLS>/${ETCD_LISTEN_PEER_URLS}}"
CLOUD_CONFIG="${CLOUD_CONFIG/<ETCD_LISTEN_CLIENT_URLS>/${ETCD_LISTEN_CLIENT_URLS}}"
CLOUD_CONFIG="${CLOUD_CONFIG/<ETCD_NETWORK_INTERFACE>/${ETCD_NETWORK_INTERFACE}}"
CLOUD_CONFIG="${CLOUD_CONFIG/<ETCD_NETWORK_INTERFACE>/${ETCD_NETWORK_INTERFACE}}"
CLOUD_CONFIG="${CLOUD_CONFIG/<ETCD_NETWORK_IPADDR>/${ETCD_NETWORK_IPADDR}}"
CLOUD_CONFIG="${CLOUD_CONFIG/<ETCD_NETWORK_PREFIX>/${ETCD_NETWORK_PREFIX}}"
CLOUD_CONFIG="${CLOUD_CONFIG/<ETCD_NETWORK_GATEWAY>/${ETCD_NETWORK_GATEWAY}}"
CLOUD_CONFIG="${CLOUD_CONFIG/<ETCD_NETWORK_DNSSERVER>/${ETCD_NETWORK_DNSSERVER}}"
CLOUD_CONFIG="${CLOUD_CONFIG/<ETCD_NTPSERVER>/${ETCD_NTPSERVER}}"
CLOUD_CONFIG="${CLOUD_CONFIG/<SSH_KEY>/${SSH_KEY}}"
CLOUD_CONFIG="${CLOUD_CONFIG/<HOSTNAME>/${HNAME}}"

echo "$CLOUD_CONFIG" > "$CONFIG_FILE"

$mkisofs -R -V config-2 -o "$CONFIGDRIVE_FILE" "$WORKDIR"

if [ "$?" -eq 0 ] ; then
    echo
    echo
    echo "Success! The config-drive image was created on ${CONFIGDRIVE_FILE}"
else
    echo
    echo
    echo "Failure! The config-drive image was not created on ${CONFIGDRIVE_FILE}"
fi
# vim: ts=4 et
