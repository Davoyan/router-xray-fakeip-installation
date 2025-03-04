# XRAY (FAKE IP + TPROXY), OpenWRT

Скрипт для установки xray на роутер с OpenWrt и реализация tproxy с роутингом по fakeip.

Если кто воспользуется полным комплектом, рекомендую в данном порядке:

1. Установка ssh, sftp и отключение dropbear (не обязательно) 
```
sh <(wget -O -https://github.com/Davoyan/router-xray-fakeip-installation/blob/main/install-ssh-sftp-and-disable-dropbear.sh)
```

2. Полное отключение ipv6 в роутере 
```
sh <(wget -O -https://github.com/Davoyan/router-xray-fakeip-installation/blob/main/disable-ipv6-full.sh)
```

3. Установка XRAY и kmod-nft-tproxy. Конфигурация cron на автоматическое обновление списков. Конфигурация network, dnsmasq, firewall, nftables для работы tproxy.
```
sh <(wget -O -https://github.com/Davoyan/router-xray-fakeip-installation/blob/main/install.sh)
```
