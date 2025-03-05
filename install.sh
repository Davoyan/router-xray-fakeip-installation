#!/bin/sh

printf "\033[32;1mInstalling packeges\033[0m\n"
opkg update && opkg install curl kmod-nft-tproxy xray-core 

printf "\033[32;1mDownloading config.json\033[0m\n"
curl -Lo /etc/xray/config.json https://github.com/Davoyan/router-xray-fakeip-installation/raw/main/install.sh

printf "\033[32;1mEnabling xray service\033[0m\n"
uci set xray.enabled.enabled='1'
uci commit xray
service xray enable

printf "\033[32;1mConfiguring update_domains script\033[0m\n"
echo "#!/bin/sh" > /etc/xray/update_domains.sh
echo "set -e" >> /etc/xray/update_domains.sh
echo "curl -Lo /usr/share/xray/runetfreedom.dat https://github.com/runetfreedom/russia-blocked-geosite/releases/latest/download/geosite.dat" >> /etc/xray/update_domains.sh
echo "service xray restart" >> /etc/xray/update_domains.sh
chmod +x /etc/xray/update_domains.sh

mkdir -p /usr/share/xray/
/etc/xray/update_domains.sh

if crontab -l | grep -q /etc/xray/update_domains.sh; then
    printf "\033[32;1mCrontab already configured\033[0m\n"

else
    crontab -l | { cat; echo "17 5 * * * /etc/xray/update_domains.sh"; } | crontab -
    printf "\033[32;1mIgnore this error. This is normal for a new installation\033[0m\n"
    /etc/init.d/cron restart
fi

printf "\033[32;1mConfiguring dnsmasq service\033[0m\n"
uci -q delete dhcp.@dnsmasq[0].resolvfile
uci set dhcp.@dnsmasq[0].noresolv="1"
uci -q delete dhcp.@dnsmasq[0].server
uci add_list dhcp.@dnsmasq[0].server="127.0.0.1#5353"
uci commit dhcp


printf "\033[32;1mConfigure network\033[0m\n"
rule_id=$(uci show network | grep -E '@rule.*name=.mark0x1.' | awk -F '[][{}]' '{print $2}' | head -n 1)
if [ ! -z "$rule_id" ]; then
    while uci -q delete network.@rule[$rule_id]; do :; done
fi

uci add network rule
uci set network.@rule[-1].name='mark0x1'
uci set network.@rule[-1].mark='0x1'
uci set network.@rule[-1].priority='100'
uci set network.@rule[-1].lookup='100'
uci commit network

echo "#!/bin/sh" > /etc/hotplug.d/iface/30-tproxy
echo "ip route add local default dev lo table 100" >> /etc/hotplug.d/iface/30-tproxy

printf "\033[32;1mConfigure firewall\033[0m\n"
rule_id2=$(uci show firewall | grep -E '@rule.*name=.Fake IP via proxy.' | awk -F '[][{}]' '{print $2}' | head -n 1)
if [ ! -z "$rule_id2" ]; then
    while uci -q delete firewall.@rule[$rule_id2]; do :; done
fi

uci add firewall rule
uci set firewall.@rule[-1].name='Block UDP 443'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest='*'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='443'
uci set firewall.@rule[-1].target='DROP'
uci set firewall.@rule[-1].family='ipv4'

uci add firewall rule
uci set firewall.@rule[-1]=rule
uci set firewall.@rule[-1].name='Fake IP via proxy'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest='*'
uci set firewall.@rule[-1].dest_ip='198.18.0.0/15'
uci add_list firewall.@rule[-1].proto='tcp'
uci add_list firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].target='MARK'
uci set firewall.@rule[-1].set_mark='0x1'
uci set firewall.@rule[-1].family='ipv4'

uci add firewall rule
uci set firewall.@rule[-1]=rule
uci set firewall.@rule[-1].name='Discord Voice via proxy'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest='*'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].target='MARK'
uci set firewall.@rule[-1].set_mark='0x1'
uci set firewall.@rule[-1].family='ipv4'
uci add firewall.@rule[-1].dest_ip='138.128.136.0/21'
uci add firewall.@rule[-1].dest_ip='162.158.0.0/15'
uci add firewall.@rule[-1].dest_ip='172.64.0.0/13'
uci add firewall.@rule[-1].dest_ip='34.0.0.0/15'
uci add firewall.@rule[-1].dest_ip='34.2.0.0/15'
uci add firewall.@rule[-1].dest_ip='35.192.0.0/12'
uci add firewall.@rule[-1].dest_ip='35.208.0.0/12'
uci add firewall.@rule[-1].dest_ip='5.200.14.128/25'
uci add firewall.@rule[-1].dest_ip='66.22.192.0/18'
uci set firewall.@rule[-1].dest_port='50000-51000'

uci commit firewall

echo "chain tproxy_marked {" > /etc/nftables.d/30-xray-tproxy.nft
echo "  type filter hook prerouting priority filter; policy accept;" >> /etc/nftables.d/30-xray-tproxy.nft
echo "  meta mark 0x1 meta l4proto { tcp, udp } tproxy ip to 127.0.0.1:12701 counter accept" >> /etc/nftables.d/30-xray-tproxy.nft
echo "}" >> /etc/nftables.d/30-xray-tproxy.nft

service xray restart && service dnsmasq restart && service network restart && service firewall restart


