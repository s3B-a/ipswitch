#!/bin/bash

#Script created by s3B-a
# ================
# IP SWITCH v1.3.1
# ================

#Color codes

GREEN="\e[32m"
CYAN="\e[36m"
YELLOW="\e[33m"
RED="\e[31m"
RES="\e[0m"
BOLD="\e[1m"


printAsciiLogo() {
	echo -e "${CYAN} +---------------------------------------------------------------+"
	echo -e "${CYAN} | ██╗██████╗     ███████╗██╗    ██╗██╗████████╗ ██████╗██╗  ██╗ |"
 	echo -e "${CYAN} | ██║██╔══██╗    ██╔════╝██║    ██║██║╚══██╔══╝██╔════╝██║  ██║ |"
	echo -e "${CYAN} | ██║██████╔╝    ███████╗██║ █╗ ██║██║   ██║   ██║     ███████║ |"
	echo -e "${CYAN} | ██║██╔═══╝     ╚════██║██║███╗██║██║   ██║   ██║     ██╔══██║ |"
	echo -e "${CYAN} | ██║██║         ███████║╚███╔███╔╝██║   ██║   ╚██████╗██║  ██║ |"
	echo -e "${CYAN} | ╚═╝╚═╝         ╚══════╝ ╚══╝╚══╝ ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝ |"
	echo -e "${CYAN} +----------------------------(v1.3.1)---------------------------+${RES}"
}

#Logs messages with color
log() {
	local color=$1
	local message=$2
	echo -e "${color}${message}${RES}"
}

#Finds the active firefox directory used by the user
findFirefoxProfile() {
	usrHome=$(eval echo "~$SUDO_USER")
	pRoot="$usrHome/.mozilla/firefox"

	if [ ! -d "$pRoot" ]; then
		log "${RED}" "Firefox directory not found! aborting..."
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

	log "${RED}" "No profile with prefs.js found..."
	return 1
}

killBrowser() {
	local browser="$1"
	if pgrep "$browser" > /dev/null; then
		log "${GREEN}" "Killing $browser..."
		pkill -9 "$browser"
	else
		log "${YELLOW}" "$browser isn't running!"
	fi
}

#Launches Brave Browser
launchBrave() {
        #Proxy to set on launch of brave via --proxy-server
        proxy=$(echo "127.0.0.1:9050")

        killBrowser brave

        launchTornet

        log "${GREEN}" "Launching brave with proxy enabled..."
        sudo -u "$SUDO_USER" brave-browser --proxy-server="socks5://$proxy" \
	--host-resolver-rules="MAP *.google.com 0.0.0.0" \
	--disable-features=NetworkService,PreloadNetworkHints,NetworkPrediction,BrowserCaptivePortalDetection \
	--proxy-bypass-list="<-loopback>" &

	echo -e "Press **Enter** to exit the script and automatically kill IP shuffler\n"
        read leave

        killBrowser brave
}

#Launches Chromium
launchChromium() {
	#Proxy to set on launch of chromium via --proxy-server
	proxy=$(echo "127.0.0.1:9050")

	killBrowser chromium

	launchTornet

	log "${GREEN}" "Launching chromium with proxy enabled..."
	sudo -u "$SUDO_USER" chromium --proxy-server="socks5://$proxy" \
	--host-resolver-rules="MAP *.google.com 0.0.0.0" \
	--disable-features=NetworkService,PreloadNetworkHints,NetworkPrediction,BrowserCaptivePortalDetection \
	--proxy-bypass-list="<-loopback>" &

	echo -e "Press **Enter** to exit the script and automatically kill IP shuffler\n"
        read leave

	killBrowser chromium
}

#Launches Firefox
launchFirefox() {
	killBrowser firefox

	#Calling the findProfile method to find the active firefox directory
	log "${YELLOW}" "Finding active directory..."
	usrPath=$(findFirefoxProfile)

	if [ -z "$usrPath" ]; then
		log "${RED}" "Failed to find Firefox profile!"
		return 1
	fi

	#Checks if user.js got moved to ideal path
	if [ -f "user.js" ]; then
		mv ./user.js $usrPath
	else
		log "${YELLOW}" "user.js is already in $usrPath"
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
user_pref("network.trr.mode", 5);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.predictor.enabled", false);
user_pref("network.captive-portal-service.enabled", false);
EOF
	fi

	#Removing conflicting proxy settings
	sed -i '/network\.proxy\./d' "$usrPath/prefs.js"
	sed -i '/network\.trr\./d' "$usrPath/prefs.js"
	sed -i '/network\.dns\./d' "$usrPath/prefs.js"

	launchTornet

	log "${GREEN}" "Opening firefox as nonroot..."
	sudo -u "$SUDO_USER" firefox &

	echo -e "Press **Enter** to exit the script and automatically kill IP shuffler\n"
        read leave

	killBrowser firefox

	#Sets proxy back to auto after closing
	cat > "$usrPath/user.js" <<EOF
user_pref("network.proxy.type", 4);
EOF

	log "${GREEN}" "Firefox set back to normal..."
	log "${GREEN}" "Returning user.js back to ipswitch dir..."
	mv $usrPath/user.js .
}

#Launches Google Chrome
launchGoogle() {
	#Proxy to set on launch of google chrome via --proxy-server
        proxy=$(echo "127.0.0.1:9050")

        killBrowser chrome

        launchTornet

        log "${GREEN}" "Launching google chrome with proxy enabled..."

	sudo -u "$SUDO_USER" google-chrome --proxy-server="socks5://$proxy" \
	--host-resolver-rules="MAP *.onion 127.0.0.1" \
	--disable-features=NetworkService,PreloadNetworkHints,NetworkPrediction,BrowserCaptivePortalDetection,HappinessTrackingSurveysForDesktop,HappinessTrackingSystem \
	--enable-features=DoNotTrackByDefault \
	--proxy-bypass-list="<-loopback>" \
	--disable-sync \
	--disable-background-networking \
	--disable-breakpad \
	--disable-default-apps \
	--disable-component-update \
	--disable-domain-reliability \
	--disable-client-side-phishing-detection \
	--disable-suggestions-service \
	--disable-translate \
	--no-default-browser-check \
	--no-first-run \
	--no-pings \
	--no-service-autorun \
	--no-experiments \
	--no-report-upload \
	--disable-google-help-tracking &

        echo -e "Press **Enter** to exit the script and automatically kill IP shuffler\n"
        read leave

        killBrowser chrome
}

#Launches Tornet and begins IP shuffling
launchTornet() {
	log "${GREEN}" "Setting up DNS protection..."

	#Launch DNS blocking for google... corpo scums...
	if [ -f "./blockgoogledns.py" ]; then
		log "${YELLOW}" "Stopping any existing DNS blockers..."
		./blockgoogledns.py stop
		sleep 1
	fi

	#Double check tor is active before running tornet
	if ! systemctl is-active --quiet tor; then
		log "${YELLOW}" "Tor service is not running, starting now..."
		systemctl start tor
		sleep 2
		if ! systemctl is-active --quiet tor; then
			log "${RED}" "Failed to start Tor service! Exiting..."
			exit 1
		fi
		log "${GREEN}" "Tor service started!"
	fi

	#Block chrome DNS servers
	log "${CYAN}" "Stopping the corpos from stealing your data..."
	if [ -f "./blockgoogledns.py" ]; then
		chmod +x blockgoogledns.py
		./blockgoogledns.py monitor &
		DNSBLOCKERPID=$!

		sleep 2

		if ! ps -p "$DNSBLOCKERPID" > /dev/null; then
			log "${RED}" "DNS blocker failed to start!"
		fi
	else
		log "${RED}" "Warning: blockgoogledns.py not found. Data may leak to the corpos."
		return 1
	fi

	log "${GREEN}" "Launching tornet..."
	tornet --interval 5 --count 0 &
	TORNET_PID=$!

	sleep 2
	if ps -p "$TORNET_PID" > /dev/null; then
		log "${GREEN}" "tornet started with PID: $TORNET_PID"
		log "${GREEN}" "IP rotation is active!"
	else
		log "${RED}" "IP rotation failed to start! check if tornet is properly installed."
		return 1
	fi
}

#Asks for root perms
if [ "$EUID" -ne 0 ]; then
	echo "Run as root"
	exec sudo "$0" "$@"
	exit
fi

#Installs Dependancies
log "${YELLOW}" "Checking if tor and tornet are installed..."
apt install tor
pip install tornet --break-system-packages
log "${GREEN}" "Installed all dependancies"

#Quickly deactivates tor if it was previously running
if systemctl is-active --quiet tor; then
	log "${YELLOW}" "Exiting tor to reset connection..."
	systemctl stop tor
	systemctl status tor
fi

#Checks if required services are running
log "${YELLOW}" "Checking tor status"
if ! systemctl is-active --quiet tor; then
	log "${YELLOW}" "tor isn't running, launching..."
	systemctl start tor
	systemctl status tor
else
	log "${GREEN}" "Tor is running!"
fi

#Checks torrc file for specific lines for DNS compatibility
log "${YELLOW}" "Checking if Tor cfg is configured properly..."
dnsExists=$(grep -c "^DNSPort 9053$" /etc/tor/torrc)
automapExists=$(grep -c "^AutomapHostsOnResolve 1$" /etc/tor/torrc)
if [ $dnsExists -eq 0 ] || [ $automapExists -eq 0 ]; then
	touch /tmp/torrc_additions

	if [ $dnsExists -eq 0 ]; then
		echo "DNSPort 9053" >> /tmp/torrc_additions
	fi

	if [ $automapExists -eq 0 ]; then
		echo "AutomapHostsOnResolve 1" >> /tmp/torrc_additions
	fi

	cat /tmp/torrc_additions >> /etc/tor/torrc

	rm -f /tmp/torrc_additions

	log "${GREEN}" "Tor cfg updated!"

	log "${YELLOW}" "Restartionig Tor to apply new cfg..."
	systemctl restart tor
	sleep 2

	if ! systemctl is-active --quiet tor; then
		log "${RED}" "Failed to restart Tor! check cfg..."
		exit 1
	else
		log "${GREEN}" "Tor restarted successfully!"
	fi
else
	log "${GREEN}" "All cfg already exists in torrc"
fi

#Checks for blockgoogledns.py script
if [ ! -f "blockgoogledns.py" ]; then
	log "${RED}" "ERROR: blockgoogledns.py is NOT in the current dirrectory."
	log "${RED}" "Please make sure the entire repo is installed and the script is in the same directory as ipswap.sh"
	exit 1
fi

printAsciiLogo

#Determine browser
log "${CYAN}" "Available browsers: firefox, chromium, brave, chrome/google"
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
elif [[ "$usrBrowser" == "chrome" || "$usrBrowser" == "google" || "$usrBrowser" == "google chrome" ]]; then
	echo "Selected Google Chrome..."
	launchGoogle
else
	echo "no selected browser... quitting..."
	if systemctl is-active --quiet tor; then
		systemctl stop tor
	fi
	exit 1
fi
