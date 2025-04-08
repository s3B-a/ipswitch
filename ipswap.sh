#!/bin/bash

if [ "$EUID" -ne 0 ]; then
	echo "Run as root"
	exec sudo "$0" "$@"
	exit
fi

if pgrep firefox > /dev/null; then
        echo "Killing firefox..."
        pkill -9 firefox
else
        echo "That fox is already dead..."
fi

echo "Checking if tor and tornet are installed..."
apt install tor
pip install tornet --break-system-packages
echo "Installed all dependancies"

echo "Checking tor status"
torService="tor"
if ! systemctl is-active $torService; then
	echo "$torService isn't running, launching..."
	systemctl start tor
	systemctl status tor
else
	echo "$torService is running!"
fi

usrPath="~/.mozilla/firefox/v2yc8mi8.default-esr/user.js"
fLine=$(head -n 1 "$usrPath")

if [["$fLine" == *'user_pref("network.proxy.type", 1);'* ]]; then
	echo "Type 1!"
elif [["$fLine" == *'user_pref("network.proxy.type", 4);' * ]]; then
	echo "Type 4, changing user.js to type 1..."
	cat > $usrPath <<EOF
	user_pref("network.proxy.type", 1);
	user_pref("network.proxy.socks", "127.0.0.1");
	user_pref("network.proxy.socks_port", 9050);
	user_pref("network.proxy.socks_version", 5);
	user_pref("network.proxy.socks_remote_dns", true);
	EOF
else
	echo "Proxy is at an unknown type, defaulting to 1..."
	cat > $usrPath <<EOF
        user_pref("network.proxy.type", 1);
        user_pref("network.proxy.socks", "127.0.0.1");
        user_pref("network.proxy.socks_port", 9050);
        user_pref("network.proxy.socks_version", 5);
        user_pref("network.proxy.socks_remote_dns", true);
        EOF
fi

echo "Launching tornet"
tornet --interval 10 --count 0 &
TORNET_PID=$!

echo "tornet started with PID: $TORNET_PID"
echo "You can stop it later with: kill $TORNET_PID if the process doesn't stop immediately"
firefox

cat > $usrPath <<EOF
user_pref("network.proxy.type", 4);
EOF

read -p "Press **Enter** to exit the script"
