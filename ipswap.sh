#!/bin/bash

#Finds the active firefox directory used by the user
findProfile() {
	usrHome=$(eval echo "~$SUDO_USER")
	ini_file="$usrHome/.mozilla/firefox/profiles.ini"

	if [ ! -f "$ini_file" ]; then
		echo "profiles.ini not found!"
		return 1
	fi

	activeP=$(awk -F='/^\[Profile[0-9]+\]/{section=$0} $1=="Default" && $2=="1"{print section} ' "$ini_file" | sed -E 's/\[Profile([0-9]+)\]/\1/')
	pPath=$(awk -F= '
        	/^\[Profile/ { in_profile=1; path=""; is_default=0 }
        	in_profile && /^Path=/ { path=$2 }
        	in_profile && /^Default=/ { is_default=$2 }
        	in_profile && path && is_default=="1" {
        	    print path; exit
        	}
    		' "$ini_file")

	if [ -n "$pPath" ]; then
		echo "$usrHome/.mozilla/firefox/$pPath"
	else
		echo "Default profiel not found!"
		return 1
	fi
}

#Asks for root perms
if [ "$EUID" -ne 0 ]; then
	echo "Run as root"
	exec sudo "$0" "$@"
	exit
fi

#Forcefully kills firefox, check README.md for more information
if pgrep firefox > /dev/null; then
        echo "Killing firefox..."
        pkill -9 firefox
else
        echo "That fox is already dead..."
fi

#Installs Dependancies
echo "Checking if tor and tornet are installed..."
apt install tor
pip install tornet --break-system-packages
echo "Installed all dependancies"

#Checks if required services are running
echo "Checking tor status"
torService="tor"
if ! systemctl is-active $torService; then
	echo "$torService isn't running, launching..."
	systemctl start tor
	systemctl status tor
else
	echo "$torService is running!"
fi

#Calling the findProfile method to find the active firefox directory
echo "Finding profile.ini..."
usrPath=$(findProfile)

#Checks if user.js got moved to ideal path
if [ -f "user.js" ]; then
	mv ./user.js $usrPath
else
	echo "user.js is already in $usrPath"
fi

#Determines proxy and changes to custom proxy when needed
fLine=$(head -n 1 "$usrPath/user.js")
if [["$fLine" == *'user_pref("network.proxy.type", 1);'* ]]; then
	echo "Type 1!"
elif [["$fLine" == *'user_pref("network.proxy.type", 4);' * ]]; then
	echo "Type 4, changing user.js to type 1..."
	cat >> $usrPath <<EOF
	user_pref("network.proxy.type", 1);
	user_pref("network.proxy.socks", "127.0.0.1");
	user_pref("network.proxy.socks_port", 9050);
	user_pref("network.proxy.socks_version", 5);
	user_pref("network.proxy.socks_remote_dns", true);
EOF
else
	echo "Proxy is at an unknown type, defaulting to 1..."
	cat >> $usrPath <<EOF
	user_pref("network.proxy.type", 1);
	user_pref("network.proxy.socks", "127.0.0.1");
	user_pref("network.proxy.socks_port", 9050);
	user_pref("network.proxy.socks_version", 5);
	user_pref("network.proxy.socks_remote_dns", true);
EOF
fi

#Launches tornet and begins IP shuffling
echo "Launching tornet"
tornet --interval 3 --count 0 &
TORNET_PID=$!

echo "tornet started with PID: $TORNET_PID"
echo "You can stop it later with: pkill -9 $TORNET_PID if the process doesn't stop immediately"

#sets proxy back to auto after closing
cat >> $usrPath <<EOF
user_pref("network.proxy.type", 4);
EOF

#su $USER -c "firefox"
read -p "Press **Enter** to exit the script and automatically kill IP shuffler"
