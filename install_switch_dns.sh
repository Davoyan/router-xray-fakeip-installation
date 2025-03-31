#!/bin/sh

printf "\033[32;1mDownloading DNS Switch script\033[0m\n"
curl -Lo /etc/xray/switch_dns.sh https://raw.githubusercontent.com/Davoyan/router-xray-fakeip-installation/main/switch_dns.sh
chmod +x /etc/xray/switch_dns.sh

if crontab -l | grep -q /etc/xray/switch_dns.sh; then
    printf "\033[32;1mCrontab for DNS Switch already configured\033[0m\n"
else
    crontab -l | { cat; echo "* * * * * /etc/xray/switch_dns.sh"; } | crontab -
    printf "\033[32;1mIgnore this errors. This is normal for a new installation\033[0m\n"
    /etc/init.d/cron restart
fi

service xray restart && service dnsmasq restart && service network restart && service firewall restart