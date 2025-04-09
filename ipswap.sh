#!/bin/bash

#Finds the active firefox directory used by the user
findProfile() {
	usrHome=$(eval echo "~$SUDO_USER")
	pRoot="$usrHome/.mozilla/firefox"

	if [ ! -d "$pRoot" ]; then
		echo "Firefox directory not found! aborting..."
		return 1
	fi

	for dir in "$pRoot"/*.default* "$pRoot"/*.esr*; do
		if [ -f $dir/prefs.js ]; then
			echo "$dir"
			return 0
		fi
	done

	echo "No profile with prefs.js found..."
	return 1
}

#Forcefully kills firefox, check README.md for more information
killFirefox() {
	if pgrep firefox > /dev/null; then
		echo "Killing firefox..."
		pkill -9 firefox
	else
		echo "That fox is already dead..."
	fi
}

#Asks for root perms
if [ "$EUID" -ne 0 ]; then
	echo "Run as root"
	exec sudo "$0" "$@"
	exit
fi

killFirefox


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
echo "Finding active directory..."
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
	echo "Proxy is type 1!"
elif [["$fLine" == *'user_pref("network.proxy.type", 4);' * ]]; then
	echo "Proxy is type 4, changing user.js to type 1..."
	cat > "$usrPath/user.js" <<EOF
user_pref("network.proxy.type", 1);
user_pref("network.proxy.socks", "127.0.0.1");
user_pref("network.proxy.socks_port", 9050);
user_pref("network.proxy.socks_version", 5);
user_pref("network.proxy.socks_remote_dns", true);
EOF
else
	echo "Proxy is at an unknown type, defaulting to 1..."
	cat > "$usrPath/user.js" <<EOF
user_pref("network.proxy.type", 1);
user_pref("network.proxy.socks", "127.0.0.1");
user_pref("network.proxy.socks_port", 9050);
user_pref("network.proxy.socks_version", 5);
user_pref("network.proxy.socks_remote_dns", true);
EOF
fi

#Removing conflicting proxy settings
sed -i '/network\.proxy\./d' "$usrPath/prefs.js"

#Launches tornet and begins IP shuffling
echo "Launching tornet"
tornet --interval 5 --count 0 &
TORNET_PID=$!

echo "tornet started with PID: $TORNET_PID"
echo "You can stop it later with: pkill -9 $TORNET_PID if the process doesn't stop immediately"

echo "Opening firefox as nonroot..."
sudo -u "$SUDO_USER" firefox &

read -p "Press **Enter** to exit the script and automatically kill IP shuffler"

killFirefox

#sets proxy back to auto after closing
cat > "$usrPath/user.js" <<EOF
user_pref("network.proxy.type", 4);
EOF
echo "Firefox set back to normal..."
