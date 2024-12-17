#!/bin/bash

# parse Office 365 for email
# write out to com.jamf.connect.state.plist
# touch an empty file if no email address found so that NT RA doesn't bail unexpectedly?

currentUser=$(stat -f %Su "/dev/console")
currentUserHome=$(dscl . read "/Users/$currentUser" NFSHomeDirectory | awk ' { print $NF } ')
uid=$(id -u "$currentUser")

plistPath="${currentUserHome}"/Library/Preferences/com.jamf.connect.state.plist

email=$(launchctl asuser "$uid" sudo -u "$currentUser" /usr/bin/defaults read com.microsoft.office OfficeActivationEmailAddress)

if [[ "{$email}" != *"@"* ]]; then
	echo "no @ found, exiting.."
    touch "{$plistPath}"
	exit 0
fi


/usr/libexec/PlistBuddy -c "Add DisplayName string" "${plistPath}" > /dev/null 2>&1
/usr/libexec/PlistBuddy -c "Set DisplayName $email" "${plistPath}" > /dev/null 2>&1

# /usr/bin/plutil -p $plistPath
