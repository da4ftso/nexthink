#!/bin/bash

# 1.0 240523 PWC
# unload Nexthink, update UPN, reload

# variables

nxtsvcPlist="/Library/LaunchDaemons/com.nexthink.collector.driver.nxtsvc.plist"
nxtcoordPlist="/Library/LaunchDaemons/com.nexthink.collector.nxtcoordinator.plist"

config="/Library/Application Support/Nexthink/config.json"

# functions
validate() {
	# check for Nexthink, bail out if not present
	if [[ ! -e $config ]]; then
	  echo "X Nexthink collector not found, exiting.."
	  exit 1
	else
	  echo "= Collector version:" "$(/usr/bin/awk -F\" '/version/ { print $4 }' "$config")"
	fi
}	

unloadPlists() {
	echo "- Unloading .plists.."
	/bin/launchctl unload "${nxtsvcPlist}"
	/bin/launchctl unload "${nxtcoordPlist}"
}

editConfig() {
	echo "> Setting config to trace.."
	/usr/bin/sed -i '' 's/\"no_import\"/\"cleartext\"/' "${config}"
}

reloadPlists() {
	echo "+ Reloading .plists.."
	/bin/launchctl load "${nxtsvcPlist}"
	/bin/launchctl load "${nxtcoordPlist}"
}


# execution

	validate
	unloadPlists
	editConfig
	reloadPlists

exit
