# XRAY (FAKE IP + TPROXY), OpenWRT

Скрипт для установки xray на роутер с OpenWrt и реализация tproxy с роутингом по fakeip. + списки доменов [Re:filter](https://github.com/1andrevich/Re-filter-lists) + discord голосовые каналы.


Внимание! xray + geosite.dat из скрипта весит около 16мб. Будьте уверены в наличии свободного места на роутере. (На ax3000t хватит)

---
Если кто воспользуется полным комплектом, рекомендую в данном порядке:

1. Установка ssh, sftp и отключение dropbear (не обязательно) 
```
sh <(wget -O - https://github.com/Davoyan/router-xray-fakeip-installation/raw/main/install-ssh-sftp-and-disable-dropbear.sh)
```

2. Полное отключение ipv6 в роутере 
```
sh <(wget -O - https://github.com/Davoyan/router-xray-fakeip-installation/raw/main/disable-ipv6-full.sh)
```


> [!TIP]
> Перед выполнением пункта 3 подготовьте данные для outbound xray, потому что интернет до их заполнения будет недоступен

3. Установка XRAY и kmod-nft-tproxy. Конфигурация cron на автоматическое обновление списков. Конфигурация network, firewall, nftables для работы tproxy. Конфигурация dnsmasq для работы fakedns
```
sh <(wget -O - https://github.com/Davoyan/router-xray-fakeip-installation/raw/main/install.sh)
```

4. Редактируем конфигурационный файл по пути /etc/xray/config.json и вписываем в outbound свои данные

5. Перезагружаем роутер или выполняем
```
service xray restart && service dnsmasq restart && service network restart && service firewall restart
```

---
> [!TIP]
> На клиентах роутера в качестве DNS должен быть указан IP роутера
