# ipswitch
## Description
IP SWITCHER UTILIZING TORNET

### What does it do??
- Automatically sets up the tor service, connects to Tornet, shuffles your IP address through various DNS servers, while automatically changing your settings within your browser to remove the hastle of going into settings and configuring a custom proxy.
  
- This script works **exclusively with linux**

## How to Run
- Download the repo ```git clone https://github.com/s3B-a/ipswitch.git```
- Once downloaded, enter the directory
- Enter ```chmod +x ipswap.sh```
- Run the program ```./ipswap.sh```

### WARNING
- When running the program, if you terminate using ```Ctrl+C```, **YOUR SYSTEM WILL CRASH**
- Changing the interval from 5 may slow your system down, anything lower than 3 and Tornet won't be able to catch up (this is due connecting too quickly to networks all around the globe)
### THIS SCRIPT IS A WORK IN PROGRESS
- Not all browsers are supported at the time of editing the only browser this functions with is firefox.
- More browsers will obtain this feature in the future

### Why kill firefox?
Killing firefox **is necessary to edit the proxy settings**. This is because you cannot edit the ```prefs.js``` file directly, as it gets overwritten by firefox when closed. The ```user.js``` file is there as a way for firefox to copy the user-controlled config and copy the settings into ```prefs.js```
