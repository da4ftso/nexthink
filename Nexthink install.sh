#!/bin/bash

# Script to install the Nexthink Collector agent using the csi.app's command-line 
# 1.7 - sanity check for key file

ERROR=0

# variables
csiAppPath="/private/var/tmp/Nexthink/csi.app/Contents/MacOS"
hostname="your-org-production.us.nexthink.cloud"
proxy="http://your.org/proxy.pac"
key="/private/var/tmp/Nexthink/your-org.txt"

# check for download, retry 3 times, bail out if not present
if [ ! -f "$csiAppPath"/csi ]; then
        counter=0
	while [ $counter -lt 3 ]; do
		/usr/local/bin/jamf policy -event install-nexthink
		sleep 300
        ((counter++))
	done
fi

if [ ! -f "$csiAppPath"/csi ]; then
	echo "Nexthink installer failed to download, exiting.."
    exit 1
fi

if [ ! -f "$key" ]; then
	echo "Product key not found, exiting.."
    exit 1
fi



# clear the quarantine flag, just in case
/usr/bin/xattr -dr com.apple.quarantine "/private/var/tmp/Nexthink/csi.app"

# install the Nextthink Collector software
$csiAppPath/csi -address "$hostname" -tcp_port 443 -key "$key" -engage enable -proxy_pac_address "$proxy" -tag 0 -ra_execution_policy signed_trusted_or_nexthink -use_assignment enable -data_over_tcp enable --clean_install

# remove installer folder
rm -rf /private/var/tmp/Nexthink

# disable/Enable Coordinator Service
launchctl bootout system /Library/LaunchDaemons/com.nexthink.collector.nxtcoordinator.plist
launchctl bootstrap system /Library/LaunchDaemons/com.nexthink.collector.nxtcoordinator.plist

exit $ERROR
