#!/bin/bash

#Script created by s3B-a
# ================
# IP SWITCH v1.2.1
# ================

printAsciiLogo() {
	echo -e "\e[36m +---------------------------------------------------------------+\e"
	echo -e "\e[36m | ██╗██████╗     ███████╗██╗    ██╗██╗████████╗ ██████╗██╗  ██╗ |"
 	echo -e "\e[36m | ██║██╔══██╗    ██╔════╝██║    ██║██║╚══██╔══╝██╔════╝██║  ██║ |"
	echo -e "\e[36m | ██║██████╔╝    ███████╗██║ █╗ ██║██║   ██║   ██║     ███████║ |"
	echo -e "\e[36m | ██║██╔═══╝     ╚════██║██║███╗██║██║   ██║   ██║     ██╔══██║ |"
	echo -e "\e[36m | ██║██║         ███████║╚███╔███╔╝██║   ██║   ╚██████╗██║  ██║ |"
	echo -e "\e[36m | ╚═╝╚═╝         ╚══════╝ ╚══╝╚══╝ ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝ |"
	echo -e "\e[36m +----------------------------(v1.2.1)---------------------------+\e[0m "
}

#Finds the active firefox directory used by the user
findFirefoxProfile() {
	usrHome=$(eval echo "~$SUDO_USER")
	pRoot="$usrHome/.mozilla/firefox"

	if [ ! -d "$pRoot" ]; then
		echo "Firefox directory not found! aborting..."
		return 1
	fi

	#Iterates through all the directories of firefox folder finding the default directory,
	#This directory will contrain pref.js which is the same directory that houses user.js
	for dir in "$pRoot"/*.default* "$pRoot"/*.esr*; do
		if [ -f $dir/prefs.js ]; then
			echo "$dir"
			return 0
		fi
	done

	echo "No profile with prefs.js found..."
	return 1
}

killBrowser() {
	local browser="$1"
	if pgrep "$browser" > /dev/null; then
		echo "Killing $browser..."
		pkill -9 "$browser"
	else
		echo "$browser isn't running!"
	fi
}

#Launches Brave Browser
launchBrave() {
        #Proxy to set on launch of brave via --proxy-server
        proxy=$(echo "127.0.0.1:9050")

        killBrowser brave

        launchTornet

        echo "Launching brave with proxy enabled..."
        sudo -u "$SUDO_USER" brave-browser --proxy-server="socks5://$proxy" &

        read -p "Press **Enter** to exit the script and automatically kill IP shuffler"

        killBrowser brave
}

#Launches Chromium
launchChromium() {
	#Proxy to set on launch of chromium via --proxy-server
	proxy=$(echo "127.0.0.1:9050")

	killBrowser chromium

	launchTornet

	echo "Launching chromium with proxy enabled..."
	sudo -u "$SUDO_USER" chromium --proxy-server="socks5://$proxy" &

	read -p "Press **Enter** to exit the script and automatically kill IP shuffler"

	killBrowser chromium
}

#Launches Firefox
launchFirefox() {
	killBrowser firefox

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
	if [[ "$fLine" == *'user_pref("network.proxy.type", 1);'* ]]; then
		echo "Proxy is type 1!"
	else
		echo "Defaulting Proxy to type 1..."
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

	killBrowser firefox

	#Sets proxy back to auto after closing
	cat > "$usrPath/user.js" <<EOF
user_pref("network.proxy.type", 4);
EOF
	echo "Firefox set back to normal..."
	echo "Returning user.js back to ipswitch dir..."
	mv $usrPath/user.js .
}

#Launches Tornet and begins IP shuffling
launchTornet() {
	echo "Launching tornet..."
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

#Installs Dependancies
echo "Checking if tor and tornet are installed..."
apt install tor
pip install tornet --break-system-packages
echo "Installed all dependancies"

#Checks if required services are running
echo "Checking tor status"
if ! systemctl is-active --quiet tor; then
	echo "tor isn't running, launching..."
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
