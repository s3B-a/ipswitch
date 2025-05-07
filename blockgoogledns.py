#!/usr/bin/env python3

# Script created by s3B-a
# =======================
# Google DNS Block v1.3.1
# =======================

import logging
import os
import re
import signal
import subprocess
import sys
import socket
import time

logging.basicConfig(
	level=logging.INFO,
	format='\033[1;36m[DNS Blocker]\033[0m %(message)s',
)
logger = logging.getLogger('DNS Blocker')

# Checks for root perms
def checkRoot():
	if os.geteuid() != 0:
		print("Script must be run as root!")
		sys.exit(1)

# Commented out since need to connect to some google domains (if using chrome, google.com)
# May be used in the future..?
# Gets the IP of a domain
# def getDomainIP(domain):
#	try:
#		ips = socket.gethostbyname_ex(domain)[2]
#		return ips
#	except socket.gaierror:
#		print(f"Could not resolve domain: {domain}")
#		return []

# Gets the browserUID
def getBrowserUID():
	browsers = ["chrome", "google-chrome", "chromium", "brave-browser"]
	browser_uids = set()
	for browser in browsers:
		try:
			pids = subprocess.check_output(["pidof", browser], stderr=subprocess.DEVNULL).decode().strip().split()
			for pid in pids:
				try:
					with open(f"/proc/{pid}/status") as f:
						for line in f:
							if line.startswith("Uid:"):
								uidFields = line.split()
								effectiveUID = int(uidFields[2])
								browser_uids.add(effectiveUID)
								logger.info(f"Found {browser} with UID: {effectiveUID}")
				except:
					continue
		except subprocess.CalledProcessError:
			pass
	return list(browser_uids)

# Verify all iptables is installed/available
def checkIptables():
	try:
		subprocess.check_output(["which", "iptables"])
		return True
	except subprocess.CalledProcessError:
		logger.error("\033[1;31miptables not found. Please install it first.\033[0m")
		return False

# Sets up blocking for google DNS servers
def block():
	logger.info("\033[1;32mSetting up firewall rules to block connections to Google DNS servers...\033[0m")

	if not checkIptables():
		return False

	endBlock()

	# Quick check to see if theres an active browser
	bUID = getBrowserUID()
	if not bUID:
		logger.warning("\033[1;33mWARNING: No browser processes found, applying system-wide blocking...\033[0m")

	googleDNS = ["8.8.8.8", "8.8.4.4"]
	googleDNSranges = [
		"8.8.8.0/24", "8.8.4.0/24", "8.34.208.0/20", "8.35.192.0/20",
		"23.236.48.0/20", "23.251.128.0/19", "34.0.0.0/15", "34.2.0.0/16",
		"34.3.0.0/23", "34.3.3.0/24", "34.3.4.0/24", "34.3.8.0/21",
		"34.3.16.0/20", "34.3.32.0/19", "34.3.64.0/18", "34.4.0.0/14",
		"34.8.0.0/13", "34.16.0.0/12", "34.32.0.0/11", "34.64.0.0/10",
		"34.96.0.0/16", "34.98.0.0/16", "34.128.0.0/10", "35.184.0.0/13",
		"35.190.0.0/17", "35.192.0.0/14", "35.196.0.0/15", "35.198.0.0/16",
		"35.199.0.0/17", "35.199.128.0/18", "35.200.0.0/13", "35.208.0.0/12",
		"35.224.0.0/12", "35.240.0.0/13", "57.140.192.0/18", "64.15.112.0/20",
		"64.233.160.0/19", "66.22.228.0/23", "66.102.0.0/20", "66.249.64.0/19",
		"66.249.80.0/20", "70.32.128.0/19", "72.14.192.0/18", "74.114.24.0/21",
		"74.125.0.0/16", "104.154.0.0/15", "104.196.0.0/14", "104.237.160.0/19",
		"107.167.160.0/19", "107.178.192.0/18", "108.59.80.0/20", "108.170.192.0/18",
		"108.177.0.0/17", "108.177.8.0/21", "130.211.0.0/16", "136.22.160.0/20",
		"136.22.176.0/21", "136.22.184.0/23", "136.22.186.0/24", "136.124.0.0/15",
		"142.250.0.0/15", "146.148.0.0/17", "152.65.208.0/22", "152.65.214.0/23",
		"152.65.218.0/23", "152.65.222.0/23", "152.65.224.0/19", "162.120.128.0/17",
		"162.216.148.0/22", "162.222.176.0/21", "172.110.32.0/21", "172.217.33.0/16",
		"172.217.34.0/16", "172.217.40.0/16", "172.253.1.0/16", "172.253.0.0/16",
		"173.194.170.0/16", "173.255.112.0/20", "192.104.160.0/23", "192.158.28.0/22",
		"192.178.0.0/24", "193.186.4.0/24", "199.36.154.0/23", "199.36.156.0/24",
		"199.192.112.0/22", "199.223.232.0/21", "207.223.160.0/20", "208.65.152.0/22",
		"208.68.108.0/22", "208.81.188.0/22", "208.117.224.0/19", "209.85.128.0/17",
		"209.107.176.0/20", "216.58.192.0/19", "216.73.80.0/20", "216.239.32.0/19",
		"216.252.220.0/22"
	]

	try:
		subprocess.run(["iptables", "-t", "nat", "-A", "OUTPUT", "-p", "udp", "--dport", "53", "-j", "REDIRECT", "--to-ports", "9053"])
		subprocess.run(["iptables", "-t", "nat", "-A", "OUTPUT", "-p", "tcp", "--dport", "53", "-j", "REDIRECT", "--to-ports", "9053"])
	except Exception as e:
		logger.error(f"\033[1;31mError setting up DNS redirection rules: {e}\033[0m")
		return False

	for uid in bUID:
		uid = str(uid)
		for dns in googleDNS:
			try:
				subprocess.run(["iptables", "-A", "OUTPUT", "-p", "tcp", "-m", "owner", "--uid-owner", uid, "-d", dns, "-j", "DROP"])
				subprocess.run(["iptables", "-A", "OUTPUT", "-p", "udp", "-m", "owner", "--uid-owner", uid, "-d", dns, "-j", "DROP"])
			except Exception as e:
				logger.error(f"\033[1;31mError setting browser-specific rules: {e}\033[0m")

	for ipR in googleDNSranges:
		try:
			# Block port 53
			subprocess.run(["iptables", "-A", "OUTPUT", "-p", "tcp", "-d", ipR, "--dport", "53", "-j", "DROP"])
			subprocess.run(["iptables", "-A", "OUTPUT", "-p", "udp", "-d", ipR, "--dport", "53", "-j", "DROP"])

			# Block DoH port 443 and DoT port 853
			subprocess.run(["iptables", "-A", "OUTPUT", "-p", "tcp", "-d", ipR, "--dport", "443", "-j", "DROP"])
			subprocess.run(["iptables", "-A", "OUTPUT", "-p", "tcp", "-d", ipR, "--dport", "853", "-j", "DROP"])
		except Exception as e:
			logger.error(f"\033[1;31mError setting range-specific rules: {e}\033[0m")
			return False

	for dns in googleDNS:
		try:
			subprocess.run(["iptables", "-A", "OUTPUT", "-d", dns, "-j", "DROP"])
		except Exception as e:
			logger.error(f"\033[1;31mError setting universal blocking rules: {e}\033[0m")

	logger.info("\033[1;32mGoogle DNS blocking rules applied successfully\033[0m")
	return True

# Removes blocking for google servers
def endBlock():
	logger.info("\033[1;32mRemoving DNS blocking rules...\033[0m")

	if not checkIptables():
		return False

	try:
		natOutput = subprocess.check_output(["iptables-save", "-t", "nat"]).decode('utf-8')
		dnsRules = [line for line in natOutput.split('\n') if "--dport 53" in line and "-j REDIRECT" in line]
		for rule in dnsRules:
			parts = rule.split()
			chain = parts[1]
			cmd = ["iptables", "-t", "nat", "-D", chain]
			for i in range(2, len(parts)):
				cmd.append(parts[i])
			try:
				subprocess.run(cmd)
			except:
				pass
	except Exception as e:
		logger.error(f"\033[1;31mError cleaning NAT table: {e}\033[0m")


	googleIdentifiers = ["8.8.8.8", "8.8.4.4", "google", "dns"]

	try:
		rules = subprocess.check_output(["iptables-save"]).decode('utf-8').split('\n')

		for rule in rules:
			if any(ident in rule.lower() for ident in googleIdentifiers) and "-A OUTPUT" in rule:
				parts = rule.split()
				if len(parts) > 1:
					cmd = ["iptables", "-D", parts[1]]
					for i in range(2, len(parts)):
						cmd.append(parts[i])
					try:
						subprocess.run(cmd)
					except:
						pass
	except Exception as e:
		logger.error(f"\033[1;31mError cleaning rule table: {e}\033[0m")

	# failsafe
	try:
		output = subprocess.check_output(["iptables", "-L", "OUTPUT", "--line-numbers"]).decode('utf-8')
		lines = output.strip().split('\n')[2:]

		rule_numbers = []
		for line in lines:
			match = re.match(r'^\s*(\d+)', line)
			if match:
				rule_numbers.append(int(match.group(1)))

		for rule in sorted(rule_numbers, reverse=True):
			subprocess.run(["iptables", "-D", "OUTPUT", str(rule)])
	except Exception as e:
		logger.error(f"\033[1;31mError cleaning OUTPUT chain: {e}\033[0m")

	logger.info("\033[1;32mDNS blocking rules removed\033[0m")
	return True

# Shows Status of iptables
def showStatus():
	logger.info("\033[1;32mCurrent iptables rules:\033[0m")
	try:
		subprocess.run(["iptables", "-L", "OUTPUT", "-v"])
		subprocess.run(["iptables", "-t", "nat", "-L", "OUTPUT", "-v"])

		natOutput = subprocess.check_output(["iptables-save", "-t", "nat"]).decode('utf-8')
		if "--to-ports 9053" in natOutput:
			logger.info("\033[1;32mDNS redirection to Tor is ACTIVE\033[0m")
		else:
			logger.warning("\033[1;31mDNS redirection to Tor is NOT ACTIVE\033[0m")

		output = subprocess.check_output(["iptables", "-L", "OUTPUT", "-v"]).decode('utf-8')
		if "8.8.8.8" in output or "8.8.4.4" in output:
			logger.info("\033[1;32mGoogle DNS blocking is ACTIVE\033[0m")
		else:
			logger.warning("\033[1;31mGoogle DNS blocking is NOT ACTIVE\033[0m")
	except Exception as e:
        	logger.error(f"\033[1;31mError displaying status: {e}\033[0m")

# Test DNS resolution
def testDNS():
	logger.info("testing DNS resolution...")

	try:
		result = subprocess.run(["dig", "google.com"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5)
		output = result.stdout.decode('utf-8')

		if "8.8.8.8" in output or "8.8.4.4" in output:
			logger.error("\033[1;31mWARNING: Google DNS (8.8.8.8/8.8.4.4) is still being used!\033[0m")
			return False
		else:
			logger.info("\033[1;32mDNS resolution is not using Google DNS\033[0m")
			return True
	except subprocess.TimeoutExpired:
		logger.warning("\033[1;33mDNS loookup timed out, this could mean blocking is working\033[0m")
		return True
	except Exception as e:
		logger.error(f"\033[1;31mError testing DNS: {e}\033[0m")
		return False

# Commands to use
def showUsage():
	print("\033[1;36mUsage:\033[0m " + sys.argv[0] + " [option]")
	print("\033[1;36mOptions:\033[0m")
	print("  \033[1;32mstart\033[0m  - Setup blocking rules")
	print("  \033[1;32mstop\033[0m  - Remove blocking rules")
	print("  \033[1;32mstatus\033[0m  - Show blocking rules status")
	print("  \033[1;32mmonitor\033[0m  - Start blocking and continuously monitor")
	print("  \033[1;32mtest\033[0m  - Test if DNS blocking is functioning")

# Handles clean exits for monitor mode
def signal_handler(sig, frame):
	print("\nRecieved signal interruption... Removing all DNS blocking rules...")
	endBlock()
	sys.exit(0)

# Monitors blocking rules and connections
def monitor():
	logger.info("\033[1;32mStarting Google DNS block monitoring mode...\033[0m")

	signal.signal(signal.SIGINT, signal_handler)
	signal.signal(signal.SIGTERM, signal_handler)

	knownUID = set()
	lastCheck = 0
	checkInterval = 10

	success = block()
	if not success:
		logger.error("\033[1;31mInitial blocking setup failed\033[0m")
		sys.exit(1)

	buid = getBrowserUID()
	for uid in buid:
		knownUID.add(str(uid))

	try:
		while True:
			currentTime = time.time()

			if currentTime - lastCheck >= checkInterval:

				# natOutput live check
				natOutput = subprocess.check_output(["iptables-save", "-t", "nat"]).decode('utf-8')
				if "--to-ports 9053" not in natOutput:
					logger.warning("\033[1;33mDNS redirection rules are missing or unapplied... reapplying...\033[0m")
					try:
						subprocess.run(["iptables", "-t", "nat", "-A", "OUTPUT", "-p", "udp", "--dport", "53", "-j", "REDIRECT", "--to-ports", "9053"])
						subprocess.run(["iptables", "-t", "nat", "-A", "OUTPUT", "-p", "tcp", "--dport", "53", "-j", "REDIRECT", "--to-ports", "9053"])
					except Exception as e:
						logger.error(f"\033[1;31mError setting up DNS redirection rules: {e}\033[0m")

				# GoogleDNS output live check
				output = subprocess.check_output(["iptables", "-L", "OUTPUT", "-v"]).decode('utf-8')
				if "8.8.8.8" not in output or "8.8.4.4" not in output:
					logger.warning("\033[1;33mGoogle DNS blocking rules are missing or unapplied... reapplying...\033[0m")
					for dns in ["8.8.8.8","8.8.4.4"]:
						try:
							subprocess.run(["iptables", "-A", "OUTPUT", "-d", dns, "-j", "DROP"])
						except Exception as e:
							logger.error(f"\033[1;31mError adding DNS block rule: {e}\033[0m")

				lastCheck = currentTime

			newUID = set(str(uid) for uid in getBrowserUID())
			for uid in newUID - knownUID:
				logger.info(f"\033[1;32mNew browser process detected with UID {uid}. Adding rules...\033[0m")
				for dns in ["8.8.8.8", "8.8.4.4"]:
					try:
						subprocess.run(["iptables", "-A", "OUTPUT", "-p", "tcp", "-m", "owner", "--uid-owner", uid, "-d", dns, "-j", "DROP"])
						subprocess.run(["iptables", "-A", "OUTPUT", "-p", "udp", "-m", "owner", "--uid-owner", uid, "-d", dns, "-j", "DROP"])
					except Exception as e:
						logger.error(f"\033[1;31mError updating rules for new UID: {e}\033[0m")
			time.sleep(2)

	except KeyboardInterrupt:
		logger.info("\033[1;33mMonitoring stopped by user\033[0m")
		endBlock()
	except Exception as e:
		logger.error(f"\033[1;31mError in monitoring: {e}\033[0m")
		endBlock()

def main():
	checkRoot()

	if len(sys.argv) < 2:
		showUsage()
		return

	command = sys.argv[1].lower()

	if command == "start":
		block()
	elif command == "stop":
		endBlock()
	elif command == "status":
		showStatus()
	elif command == "monitor":
		monitor()
	elif command == "test":
		testDNS()
	else:
		showUsage()

if __name__ == "__main__":
	main()
