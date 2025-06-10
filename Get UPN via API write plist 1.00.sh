#!/bin/bash

# call Jamf API to get Email from location
# write out to com.jamf.connect.state.plist

# remember that if you're using recon to generate id,
# run this from root - TO-DO: add NE=1 to check

username="apimodernuser"
password="ThisIsHowWeDoThingsN0w"
url="https://casper.hcsc.net:8443"

currentUser=$(stat -f %Su "/dev/console")
currentUserHome=$(dscl . read "/Users/$currentUser" NFSHomeDirectory | awk ' { print $NF } ')

id=$(/usr/local/bin/jamf recon | awk -F'>|<' '{ print $3 }' | tr -d '\n')
echo "ID: $id"

plistPath="${currentUserHome}"/Library/Preferences/com.jamf.connect.state.plist

# Variable declarations
bearerToken=""
tokenExpirationEpoch="0"

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

getBearerToken

checkTokenExpiration

getEmail

writeToPlist

invalidateToken

exit