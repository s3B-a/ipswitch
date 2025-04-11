#!/bin/bash

#Script created by s3B-a
# ================
# IP SWITCH v1.1.0
# ================

printAsciiLogo() {
	echo -e "\e[36m +---------------------------------------------------------------+\e"
	echo -e "\e[36m | ██╗██████╗     ███████╗██╗    ██╗██╗████████╗ ██████╗██╗  ██╗ |"
 	echo -e "\e[36m | ██║██╔══██╗    ██╔════╝██║    ██║██║╚══██╔══╝██╔════╝██║  ██║ |"
	echo -e "\e[36m | ██║██████╔╝    ███████╗██║ █╗ ██║██║   ██║   ██║     ███████║ |"
	echo -e "\e[36m | ██║██╔═══╝     ╚════██║██║███╗██║██║   ██║   ██║     ██╔══██║ |"
	echo -e "\e[36m | ██║██║         ███████║╚███╔███╔╝██║   ██║   ╚██████╗██║  ██║ |"
	echo -e "\e[36m | ╚═╝╚═╝         ╚══════╝ ╚══╝╚══╝ ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝ |"
	echo -e "\e[36m +----------------------------(v1.1.0)---------------------------+\e[0m "
}

#Finds the active firefox directory used by the user
findFirefoxProfile() {
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

#Forcefully kills chromium, check README.md for more information
killChromium() {
	if pgrep chromium > /dev/null; then
		echo "Killing Chromium..."
		pkill -9 chromium
	else
		echo "Chromium lost it's chrome choom"
	fi
}

#Forcefully kills Brave Browser, check README.md for more information
killBrave() {
        if pgrep brave > /dev/null; then
                echo "Killing Brave Browser..."
                pkill -9 brave
        else
                echo "Brave lion became a house cat..."
        fi
}

#Launches Chromium
launchChromium() {
	#Proxy to set on launch of chromium via --proxy-server
	proxy=$(echo "127.0.0.1:9050")

	killChromium

	launchTornet

	echo "Launching chromium with proxy enabled..."
	sudo -u "$SUDO_USER" chromium --proxy-server="socks5://$proxy" &

	read -p "Press **Enter** to exit the script and automatically kill IP shuffler"

	killChromium
}

#Launches Firefox
launchFirefox() {
	killFirefox

	#Calling the findProfile method to find the active firefox directory
	echo "Finding active directory..."
	usrPath=$(findFirefoxProfile)

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

	launchTornet

	echo "Opening firefox as nonroot..."
	sudo -u "$SUDO_USER" firefox &

	read -p "Press **Enter** to exit the script and automatically kill IP shuffler"

	killFirefox

	#Sets proxy back to auto after closing
	cat > "$usrPath/user.js" <<EOF
user_pref("network.proxy.type", 4);
EOF
	echo "Firefox set back to normal..."
}

#Launches Brave Browser
launchBrave() {
        #Proxy to set on launch of brave via --proxy-server
        proxy=$(echo "127.0.0.1:9050")

        killBrave

        launchTornet

        echo "Launching brave with proxy enabled..."
        sudo -u "$SUDO_USER" brave-browser --proxy-server="socks5://$proxy" &

        read -p "Press **Enter** to exit the script and automatically kill IP shuffler"

        killBrave
}


#Launches Tornet and begins IP shuffling
launchTornet() {
	echo "Launching tornet"
	tornet --interval 5 --count 0 &
	TORNET_PID=$!

	echo "tornet started with PID: $TORNET_PID"
	echo "You can stop it later with: pkill -9 $TORNET_PID if the process doesn't stop immediately"
}

#Asks for root perms
if [ "$EUID" -ne 0 ]; then
	echo "Run as root"
	exec sudo "$0" "$@"
	exit
fi

Installs Dependancies
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

printAsciiLogo

#Determine browser
echo "Enter your browser: "
read -r usrBrowser

usrBrowser=$(echo "$usrBrowser" | tr '[:upper:]' '[:lower:]')

#If statement for all available browsers
if [[ "$usrBrowser" == "chromium" ]]; then
	echo "Selected chromium..."
	launchChromium
elif [[ "$usrBrowser" == "firefox" ]]; then
	echo "Selected firefox..."
	launchFirefox
elif [[ "$usrBrowser" == "brave" || "$usrBrowser" == "brave-browser" || "$usrBrowser" == "brave browser" ]]; then
	echo "Selected Brave Browser..."
	launchBrave
else
	echo "no selected browser... quitting..."
fi
