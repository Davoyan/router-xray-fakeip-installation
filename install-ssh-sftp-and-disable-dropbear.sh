#!/bin/sh
opkg update
opkg install openssh-server openssh-sftp-server

CONFIG_FILE="/etc/ssh/sshd_config"


sed -i -E 's/^#?(Port) .*/\1 22/' $CONFIG_FILE
sed -i -E 's/^#?(PermitRootLogin) .*/\1 yes/' $CONFIG_FILE
sed -i -E 's/^#?(PasswordAuthentication) .*/\1 yes/' $CONFIG_FILE

/etc/init.d/sshd enable
/etc/init.d/sshd restart
/etc/init.d/dropbear stop
/etc/init.d/dropbear disable
