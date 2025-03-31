#!/bin/sh

CONF="/etc/config/dhcp"
STATE_FILE="/tmp/xray_state"

if [ -f "$STATE_FILE" ]; then
    PREV_STATE=$(cat "$STATE_FILE")
else
    PREV_STATE=""
fi

if /etc/init.d/xray status | grep -q "running"; then
    sed -i "s|list server '77.88.8.8#53'|list server '127.0.0.1#5353'|" "$CONF"
	CURRENT_STATE="1"
else
    sed -i "s|list server '127.0.0.1#5353'|list server '77.88.8.8#53'|" "$CONF"
	CURRENT_STATE="0"
fi

if [ "$PREV_STATE" != "$CURRENT_STATE" ]; then
    echo "$CURRENT_STATE" > "$STATE_FILE"
    /etc/init.d/dnsmasq restart
fi
