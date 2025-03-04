#!/bin/sh
opkg update
opkg install openssh-server openssh-sftp-server

CONFIG_FILE="/etc/ssh/sshd_config"

# Расскомментируем и изменяем нужные параметры
sed -i -E 's/^#?(Port) .*/\1 22/' $CONFIG_FILE
sed -i -E 's/^#?(PermitRootLogin) .*/\1 yes/' $CONFIG_FILE
sed -i -E 's/^#?(PasswordAuthentication) .*/\1 yes/' $CONFIG_FILE

# Перезапускаем SSH для применения изменений
/etc/init.d/sshd restart
/etc/init.d/dropbear stop
/etc/init.d/dropbear disable
