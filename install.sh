# #!/bin/sh

println() { printf "\033[32;1m$*\033[0m\n"; }

parse_vless_url() {
    url=$1
    clean_url=${url#*://}

    c_uuid=${clean_url%%@*}
    after=${clean_url#*@}

    hostport=${after%%\?*}
    c_host=${hostport%%:*}
    c_port=${hostport##*:}

    temp=${after#*\?}
    case "$temp" in
        *#*)
            query=${temp%%#*}
            c_hash=${temp#*#}
            ;;
        *)
            query=$temp
            c_hash=
            ;;
    esac

    IFS='&'
    set -- $query
    for pair; do
        key=${pair%%=*}
        value=${pair#*=}
        case "$key" in
            type)       c_type=$value ;;
            security)   c_security=$value ;;
            pbk)        c_pbk=$value ;;
            sni)        c_sni=$value ;;
            flow)       c_flow=$value ;;
            fp)         c_fp=$value ;;
            sid)        c_sid=$value ;;
            *)          ;;
        esac
    done

    if [ -z "$c_uuid" ] || [ -z "$c_host" ] || [ -z "$c_port" ] \
       || [ -z "$c_type" ] || [ -z "$c_security" ] \
       || [ -z "$c_pbk" ] || [ -z "$c_sni" ]; then
        echo "Incorrect vless:// URL"
        exit 1
    fi

    c_flow=${c_flow:-none}
    c_fp=${c_fp:-chrome}
    c_sid=${c_sid:-""}

    vless_json=$(printf '{"uuid":"%s","host":"%s","port":"%s","type":"%s","security":"%s","pbk":"%s","sni":"%s","flow":"%s","fp":"%s","sid":"%s"' \
        "$c_uuid" "$c_host" "$c_port" "$c_type" "$c_security" "$c_pbk" "$c_sni" "$c_flow" "$c_fp" "$c_sid")

    [ -n "$c_hash" ] && vless_json=$(printf '%s,"hash":"%s"' "$vless_json" "$c_hash")

    vless_json="$vless_json}"
}

while true; do
    println "Use vless:// url for setup xray?"
    println "==> [Y]es [C]onfigure manually or (1, 2)"
    printf "\033[32;1m==> \033[0m"
    read -r answer

    case "$answer" in
        [Yy]|1)
            println "\n==> Enter vless url"
            printf "\033[32;1m==> \033[0m"
            read -r vless_url
            parse_vless_url "$vless_url"
            use_vless_url=true
            break
            ;;
        [Cc]|2)
            break
            ;;
        *)
            println "\nUnknown answer $answer\n"
            ;;
    esac
done

println "\nInstalling packages"
opkg update && opkg install curl jq kmod-nft-tproxy xray-core

println "Downloading config.json"
curl -Lo /etc/xray/config.json https://raw.githubusercontent.com/Davoyan/router-xray-fakeip-installation/main/config.json

if [ use_vless_url ]; then
    jq --argjson vless_json "$vless_json" -r '.outbounds[0].tag += ""
        | .outbounds[0].settings.vnext[0].address = $vless_json.host
        | .outbounds[0].settings.vnext[0].port = ($vless_json.port | tonumber)
        | .outbounds[0].settings.vnext[0].users[0].id = $vless_json.uuid
        | .outbounds[0].settings.vnext[0].users[0].flow = $vless_json.flow
        | .outbounds[0].streamSettings.network = $vless_json.type
        | .outbounds[0].streamSettings.security = $vless_json.security' /etc/xray/config.json > tmp.json && mv tmp.json /etc/xray/config.json

    if [ "$c_security" = "reality" ]; then
        jq --argjson vless_json "$vless_json" -r '.outbounds[0].streamSettings.realitySettings.serverName = $vless_json.sni
            | .outbounds[0].streamSettings.realitySettings.fingerprint = $vless_json.fp
            | .outbounds[0].streamSettings.realitySettings.publicKey = $vless_json.pbk
            | .outbounds[0].streamSettings.realitySettings.shortId = $vless_json.sid' /etc/xray/config.json > tmp.json && mv tmp.json /etc/xray/config.json
    elif [ "$c_security" = "tls" ]; then
        jq --argjson vless_json "$vless_json" -r 'del(.outbounds[0].streamSettings.realitySettings)
            | .outbounds[0].streamSettings.tlsSettings = {}
            | .outbounds[0].streamSettings.tlsSettings.serverName = $vless_json.sni
            | .outbounds[0].streamSettings.tlsSettings.fingerPrint = $vless_json.fp' /etc/xray/config.json > tmp.json && mv tmp.json /etc/xray/config.json
    fi
fi

println "Enabling xray service"
uci set xray.enabled.enabled='1'
uci commit xray
service xray enable

println "Configuring update_domains script"
echo "#!/bin/sh" > /etc/xray/update_domains.sh
echo "set -e" >> /etc/xray/update_domains.sh
echo "curl -Lo /usr/share/xray/refilter.dat https://github.com/1andrevich/Re-filter-lists/releases/latest/download/geosite.dat" >> /etc/xray/update_domains.sh
echo "service xray restart" >> /etc/xray/update_domains.sh
chmod +x /etc/xray/update_domains.sh

mkdir -p /usr/share/xray/
/etc/xray/update_domains.sh

if crontab -l | grep -q /etc/xray/update_domains.sh; then
    println "Crontab already configured"

else
    crontab -l | { cat; echo "17 5 * * * /etc/xray/update_domains.sh"; } | crontab -
    println "Ignore this error. This is normal for a new installation"
    /etc/init.d/cron restart
fi

println "Configuring dnsmasq service"
uci -q delete dhcp.@dnsmasq[0].resolvfile
uci set dhcp.@dnsmasq[0].noresolv="1"
uci -q delete dhcp.@dnsmasq[0].server
uci add_list dhcp.@dnsmasq[0].server="127.0.0.1#5353"
echo "nameserver 127.0.0.1" > /etc/resolv.conf
uci commit dhcp

RC_LOCAL="/etc/rc.local"
grep -q "ethtool -K eth0 tso off" "$RC_LOCAL" || sed -i "/^exit 0/i ethtool -K eth0 tso off" "$RC_LOCAL"
grep -q "(sleep 10 && service xray restart)" "$RC_LOCAL" || sed -i "/^exit 0/i (sleep 10 && service xray restart)" "$RC_LOCAL"
grep -q "(sh && /etc/xray/update_domains.sh) &" "$RC_LOCAL" || sed -i "/^exit 0/i (sh && /etc/xray/update_domains.sh) &" "$RC_LOCAL"

println "Configure network"
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

println "Configure firewall"
rule_id2=$(uci show firewall | grep -E '@rule.*name=.Fake IP via proxy.' | awk -F '[][{}]' '{print $2}' | head -n 1)
if [ ! -z "$rule_id2" ]; then
    while uci -q delete firewall.@rule[$rule_id2]; do :; done
fi
rule_id3=$(uci show firewall | grep -E '@rule.*name=.Block UDP 443.' | awk -F '[][{}]' '{print $2}' | head -n 1)
if [ ! -z "$rule_id3" ]; then
    while uci -q delete firewall.@rule[$rule_id3]; do :; done
fi
rule_id4=$(uci show firewall | grep -E '@rule.*name=.Discord Voice via proxy.' | awk -F '[][{}]' '{print $2}' | head -n 1)
if [ ! -z "$rule_id4" ]; then
    while uci -q delete firewall.@rule[$rule_id4]; do :; done
fi

uci add firewall rule
uci set firewall.@rule[-1].name='Block UDP 443'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest='*'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='443'
uci set firewall.@rule[-1].target='REJECT'

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
uci set firewall.@rule[-1].name='Discord Voice via proxy'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest='*'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].target='MARK'
uci set firewall.@rule[-1].set_mark='0x1'
uci set firewall.@rule[-1].family='ipv4'
uci set firewall.@rule[-1].dest_port='50000-51000'
uci add_list firewall.@rule[-1].dest_ip='138.128.136.0/21'
uci add_list firewall.@rule[-1].dest_ip='162.158.0.0/15'
uci add_list firewall.@rule[-1].dest_ip='172.64.0.0/13'
uci add_list firewall.@rule[-1].dest_ip='34.0.0.0/15'
uci add_list firewall.@rule[-1].dest_ip='34.2.0.0/15'
uci add_list firewall.@rule[-1].dest_ip='35.192.0.0/12'
uci add_list firewall.@rule[-1].dest_ip='35.208.0.0/12'
uci add_list firewall.@rule[-1].dest_ip='5.200.14.128/25'
uci add_list firewall.@rule[-1].dest_ip='66.22.192.0/18'

uci commit firewall

echo "chain tproxy_marked {" > /etc/nftables.d/30-xray-tproxy.nft
echo "  type filter hook prerouting priority filter; policy accept;" >> /etc/nftables.d/30-xray-tproxy.nft
echo "  meta mark 0x1 meta l4proto { tcp, udp } tproxy ip to 127.0.0.1:12701 counter accept" >> /etc/nftables.d/30-xray-tproxy.nft
echo "}" >> /etc/nftables.d/30-xray-tproxy.nft

service xray restart && service dnsmasq restart && service network restart && service firewall restart
