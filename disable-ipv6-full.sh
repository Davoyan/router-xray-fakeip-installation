uci set 'network.lan.ipv6=0'
uci set 'network.wan.ipv6=0'
uci set 'dhcp.lan.dhcpv6=disabled'
uci commit

uci -q delete dhcp.lan.dhcpv6
uci -q delete dhcp.lan.ra
uci commit

uci set network.lan.delegate="0"
uci commit

uci -q delete network.globals.ula_prefix
uci commit

/etc/init.d/odhcpd disable
/etc/init.d/odhcpd stop

uci commit

sysctl -w net.ipv6.conf.all.disable_ipv6=1
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1

uci set dhcp.@dnsmasq[0].filter_aaaa='1'
uci commit
service dnsmasq restart
printf "\033[32;1mDont forget to reboot\033[0m\n"
