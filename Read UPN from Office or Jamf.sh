#!/bin/bash

# checks for existence of Office 365 activation,
#    OR
# makes API call to Jamf Pro to get assigned user email from Inventory
# (not LDAP),
#   THEN
# writes email (UPN) out to 'fake' Jamf Connect plist,

username="apiuser"
password="apipassword"
url="https://jamf.domain.tld"

currentUser=$(stat -f %Su "/dev/console")
currentUserHome=$(dscl . read "/Users/$currentUser" NFSHomeDirectory | awk ' { print $NF } ')
uid=$(id -u "$currentUser")

emailPath="${currentUserHome}"/Library/Preferences/com.microsoft.office.plist
plistPath="${currentUserHome}"/Library/Preferences/com.jamf.connect.state.plist

# Variable declarations
bearerToken=""
tokenExpirationEpoch="0"


# functions

getOfficeActivation() {
	email=$(launchctl asuser "$uid" sudo -u "$currentUser" /usr/bin/defaults read com.microsoft.office OfficeActivationEmailAddress)
}

getJamfID() {
        id=$(/usr/local/bin/jamf recon | awk -F'>|<' '{ print $3 }' | tr -d '\n')
}

getBearerToken() {
	response=$(curl -s -u "$username":"$password" "$url"/api/v1/auth/token -X POST)
	bearerToken=$(echo "$response" | plutil -extract token raw -)
	tokenExpiration=$(echo "$response" | plutil -extract expires raw - | awk -F . '{print $1}')
	tokenExpirationEpoch=$(date -j -f "%Y-%m-%dT%T" "$tokenExpiration" +"%s")
}

checkTokenExpiration() {
    nowEpochUTC=$(date -j -f "%Y-%m-%dT%T" "$(date -u +"%Y-%m-%dT%T")" +"%s")
    if [[ tokenExpirationEpoch -gt nowEpochUTC ]]
    then
        echo "Token valid until the following epoch time: " "$tokenExpirationEpoch"
    else
        echo "No valid token available, getting new token"
        getBearerToken
        sleep 3
    fi
}

invalidateToken() {
	responseCode=$(curl -w "%{http_code}" -H "Authorization: Bearer ${bearerToken}" "$url"/api/v1/auth/invalidate-token -X POST -s -o /dev/null)
	if [[ ${responseCode} == 204 ]]
	then
		echo "Token successfully invalidated"
		bearerToken=""
		tokenExpirationEpoch="0"
	elif [[ ${responseCode} == 401 ]]
	then
		echo "Token already invalid"
	else
		echo "An unknown error occurred invalidating the token"
	fi
}

getEmail() {
	email=$(curl -s -X GET $url/api/v1/computers-inventory/"${id}"?section=USER_AND_LOCATION -H 'accept: application/json' -H "Authorization: Bearer ${bearerToken}" | awk '/email/ { print $NF }' | sed 's/[,]//g' | sed 's/\r$//' )
}

writeToPlist() {
	/usr/libexec/PlistBuddy -c "Add DisplayName string" "${plistPath}" > /dev/null 2>&1
	/usr/libexec/PlistBuddy -c "Set DisplayName $email" "${plistPath}" > /dev/null 2>&1
	/usr/bin/plutil -p "${plistPath}"
}


# main
if [ ! -e "$emailPath" ]; then
	getJamfID
	getBearerToken
	checkTokenExpiration
	getEmail
	echo "Wrote plist via Jamf."
    writeToPlist
	invalidateToken

else
	getOfficeActivation
	echo "Wrote plist via Office."    
	writeToPlist

fi

exit
