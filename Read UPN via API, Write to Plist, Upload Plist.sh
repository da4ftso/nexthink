#!/bin/bash

# call Jamf API to get Email from location
# write to com.jamf.connect.state.plist
# duplicate the plist to tmp
# curl the tmp plist to Inventory > Attachments
# rm the tmp plist

username="API_user" # with Computers > Update privs, not just API privs
password="API_password"
url="https://your.jamfpro.tld"

currentUser=$(stat -f %Su "/dev/console")
currentUserHome=$(dscl . read "/Users/$currentUser" NFSHomeDirectory | awk ' { print $NF } ')

serial=$(ioreg -c IOPlatformExpertDevice -d 2 | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')

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
        echo "Token valid until epoch time: " "$tokenExpirationEpoch"
    else
        echo "No valid token, retrying"
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

getDeviceID() {
	id=$(curl -s -H "Accept: xml/text" -H "Authorization: Bearer ${bearerToken}" "$url"/JSSResource/computers/serialnumber/"$serial" | xmllint --xpath '/computer/general/id/text()' -)
}

getEmail() {
	email=$(curl -s -X GET $url/api/v1/computers-inventory/"${id}"?section=USER_AND_LOCATION -H 'accept: application/json' -H "Authorization: Bearer ${bearerToken}" | awk '/email/ { print $NF }' | sed 's/[,]//g' | sed 's/\r$//' )
}

writeToPlist() {
	/usr/libexec/PlistBuddy -c "Add DisplayName string" "${plistPath}" > /dev/null 2>&1
	/usr/libexec/PlistBuddy -c "Set DisplayName $email" "${plistPath}" > /dev/null 2>&1
	/usr/bin/plutil -p "${plistPath}"
}

uploadPlist() {
        ditto "$plistPath" /var/tmp
	curl -s -k -H "Authorization: Bearer ${bearerToken}" -X POST $url/api/v1/computers-inventory/"${id}"/attachments -H 'accept: application/json' -H 'Content-Type: multipart/form-data' -F 'file=@/var/tmp/com.jamf.connect.state.plist'
        rm /var/tmp/com.jamf.connect.state.plist
}

getBearerToken

checkTokenExpiration

getDeviceID

getEmail

writeToPlist

uploadPlist

invalidateToken

exit
