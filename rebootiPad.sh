#!/bin/zsh

# Created by Vasean Everett

# Import custom bash functions
source "<PATH/TO/CUSTOM/FUNCTIONS>"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Prompt the user for an asset tag and validate it. If it is valid, gather
# device information from the jss to reboot the device.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define Variables

apiPassPhrase="<PASSPHRASE>"
jssUser="<APIUSERNAME>"
jssPass=$(DecryptString "$apiString" "$apiPassPhrase")

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define functions

promptForAssetTag() {
	enteredTag=$(osascript -e 'set answer to text returned of (display dialog "Please scan or enter the asset tag:" with icon POSIX file "/Library/User Pictures/OPUSDICON.png"buttons {"Cancel", "OK"} default button "OK" default answer "")')
	if [ "$?" != "0" ] ; then
		echo "User cancelled. Exiting..."
		exit 1
	fi
}

invalidTagAlert() {
	runAsUser osascript -e 'set theAlertText to "You entered: '$enteredTag'"
set theAlertMessage to "That is not a valid asset tag."
display alert theAlertText message theAlertMessage' >/dev/null 2>&1
}

notFoundAlert() {
	runAsUser osascript -e 'set theAlertText to "Device not found: '$enteredTag'"
set theAlertMessage to "An iPad with the asset tag you entered could not be found."
display alert theAlertText message theAlertMessage' >/dev/null 2>&1
}

validateAssetTag(){
	case "$enteredTag" in
		# T-****
		T-[0-9][0-9][0-9][0-9])
			tagIsValid=0
		;;
		# A-****
		A-[0-9][0-9][0-9][0-9])
			tagIsValid=0
		;;
		# T30***
		T30[0-9][0-9][0-9])
			tagIsValid=0
		;;
		# T-30***
		T-30[0-9][0-9][0-9])
			enteredTag=$(printf "$enteredTag" | sed 's/-//')
			printf "Corrected Asset Tag: $enteredTag\n"
			tagIsValid=0
		;;
		# t-****
		t-[0-9][0-9][0-9][0-9])
			enteredTag=$(printf "$enteredTag" | sed 's/t/T/')
			printf "Corrected Asset Tag: $enteredTag\n"
			tagIsValid=0
		;;
		# t****
		t[0-9][0-9][0-9][0-9])
			enteredTag=$(printf "$enteredTag" | sed 's/t/T-/')
			printf "Corrected Asset Tag: $enteredTag\n"
			tagIsValid=0
		;;
		# T****
		T[0-9][0-9][0-9][0-9])
			enteredTag=$(printf "$enteredTag" | sed 's/T/T-/')
			printf "Corrected Asset Tag: $enteredTag\n"
			tagIsValid=0
		;;
		# a-****
		a-[0-9][0-9][0-9][0-9])
			enteredTag=$(printf "$enteredTag" | sed 's/a/A/')
			printf "Corrected Asset Tag: $enteredTag\n"
			tagIsValid=0
		;;
		# a****
		a[0-9][0-9][0-9][0-9])
			enteredTag=$(printf "$enteredTag" | sed 's/a/A-/')
			printf "Corrected Asset Tag: $enteredTag\n"
			tagIsValid=0
		;;
		# A****
		A[0-9][0-9][0-9][0-9])
			enteredTag=$(printf "$enteredTag" | sed 's/A/A-/')
			printf "Corrected Asset Tag: $enteredTag\n"
			tagIsValid=0
		;;
		*)
			tagIsValid=1
			invalidTagAlert
		;;
	esac
}

getAssetTag() {
	promptForAssetTag
	validateAssetTag
	while [[ $tagIsValid -ne 0 ]]
	do
		promptForAssetTag
		validateAssetTag
	done
}

getiPadSerial() {
	if [[ $tagIsValid -eq 0 ]]; then
		endpoint="JSSResource/mobiledevices/match/"
		serial=$(curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint}${enteredTag} -X GET | xmllint --xpath '/mobile_devices/mobile_device/serial_number/text()' -)
	fi
}

getDeviceInformation() {
	if [[ $tagIsValid -eq 0 ]]
	then
		endpoint="JSSResource/mobiledevices/serialnumber/"
		deviceInformation=$(curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint}${serial} -X GET)
		assetTag=$(printf "${deviceInformation}" | xmllint --xpath '/mobile_device/general/asset_tag/text()' - 2>/dev/null)
		deviceID=$(printf "${deviceInformation}" | xmllint --xpath '/mobile_device/general/id/text()' - 2>/dev/null)
		deviceModel=$(printf "${deviceInformation}" | xmllint --xpath '/mobile_device/general/model/text()' - 2>/dev/null)
	else
		printf "Tag is invalid\n"
	fi
}

validateDevice() {
	if [[ $(printf "$deviceModel" | grep -e "iPad") ]]; then
		isiPad=0
		printf "Device is an iPad\n"
	else
		isiPad=1
	fi
}

restartDevice() {
	if [[ ! -z "$serial" ]]; then
		endpoint="JSSResource/mobiledevicecommands/command/RestartDevice/id/$deviceID"
		curl -su ${jssUser}:${jssPass} -H "Content-type: text/xml" ${jssURL}${endpoint} -X POST 1>/dev/null
		deviceFound=0
	fi
}

notify(){
	if [[ ! -z $serial ]]; then
		playAlert
		runAsUser osascript -e 'set theAlertText to "Rebooting iPad: '$assetTag'"
set theAlertMessage to "iPad will restart shortly."
display alert theAlertText message theAlertMessage' >/dev/null 2>&1
	else
		playAlert
		notFoundAlert
	fi
}

rebootiPad() {
	getAssetTag
	getiPadSerial
	getDeviceInformation
	validateDevice
	restartDevice
	notify
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# main

rebootiPad

exit 0