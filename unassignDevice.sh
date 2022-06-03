#!/bin/zsh

# Created by Vasean Everett

# Import custom bash functions
source "<PATH/TO/CUSTOM/FUNCTIONS>"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Get members of the smart group "Improperly Named". For each member of the #
# smart group, get the asset tag of the device and set it as the hostname.	#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define Variables

apiPassPhrase="<PASSPHRASE>"
jssUser="<APIUSERNAME>"
jssPass=$(DecryptString "$apiString" "$apiPassPhrase")

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define functions

getXML() {
	# Get the serial numbers of all devices in "Improperly Named" smart group (ID: 22)
	endpoint="JSSResource/mobiledevicegroups/id/22"
	xml=$(curl -X GET -u ${jssUser}:${jssPass} ${jssURL}${endpoint} -H "accept: application/xml")
	devices=($(printf "$xml" | xmllint --format - | awk -F'>|<' '/<serial_number>/{print $3}' | sort -n))
}

getDeviceInfo() {
	# API call to retrieve the device inventory information
	# Parse inventory information for the asset tag and serial number of the device
	endpoint="JSSResource/mobiledevices/serialnumber/"
	xml=$(curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint}${serial} -X GET)
	assetTag=$(printf "${xml}" | xmllint --xpath '/mobile_device/general/asset_tag/text()' - 2>/dev/null)
	deviceID=$(printf "${xml}" | xmllint --xpath '/mobile_device/general/id/text()' - 2>/dev/null)
}

setMobileDeviceName() {
	# API call to set mobile device name
	endpoint="JSSResource/mobiledevicecommands/command/DeviceName/${assetTag}/id/${deviceID}"
	curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint} -X POST 1>/dev/null
}

fixiPadHostname() {
	getXML
		for serial in ${devices[@]}
		do
			getDeviceInfo
			setMobileDeviceName
			printf "Set device \"$serial\" name to \"$assetTag\"\n"
		done
	
	printLongDuration
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# main

fixiPadHostname

exit 0