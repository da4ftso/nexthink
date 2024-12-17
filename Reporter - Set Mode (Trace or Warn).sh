#!/bin/bash

# pass Jamf Pro parameter 4 as the mode: Trace or Warn
#  run script as a Before and set to Trace
#  run Reporter as its own script/step
#  run script again as After and set back to Warn

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

setToTrace() {
	echo "> Setting config to trace.."
	/usr/bin/sed -i '' 's/\"warning\"/\"trace\"/' "${config}"
}

setToWarn() {
	echo "> Setting config to warning.."
	/usr/bin/sed -i '' 's/\"trace\"/\"warning\"/' "${config}"
}

reloadPlists() {
	echo "+ Reloading .plists.."
	/bin/launchctl load "${nxtsvcPlist}"
	/bin/launchctl load "${nxtcoordPlist}"
}

# execution

	validate
	unloadPlists
    if [[ "${4}" == "trace" || "${4}" == "Trace" || "${4}" == "TRACE" ]]; then
    	setToTrace
        delay=900
    elif [[ "${4}" == "warn" || "${4}" == "Warn" || "${4}" == "WARN" ]]; then
    	setToWarn
        delay=0
    fi
	reloadPlists
	sleep $delay
