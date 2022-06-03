#!/bin/zsh

# Created by Vasean Everett

# Import custom bash functions
source "<PATH/TO/CUSTOM/FUNCTIONS>"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update iPadOS for members of the specified group by group id
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define Variables

apiPassPhrase="<PASSPHRASE>"
jssUser="<APIUSERNAME>"
jssPass=$(DecryptString "$apiString" "$apiPassPhrase")
count=0

#	Get members of "Elementary Labs" group
groupID=78

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define functions

getXML() {
		endpoint="JSSResource/mobiledevicegroups/id/${groupID}"
		xml=$(curl -X GET -u ${jssUser}:${jssPass} ${jssURL}${endpoint} -H "accept: application/xml")
		devices=($(printf "$xml" | xmllint --format - | awk -F'>|<' '/<serial_number>/{print $3}' | sort -n))
}

getMobileDeviceInformation() {
	# Get the asset tag and device id
	endpoint="JSSResource/mobiledevices/serialnumber/${serial}"
	inventoryData=$(curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint} -X GET)
	assetTag=$(printf "${inventoryData}" | xmllint --xpath '/mobile_device/general/asset_tag/text()' - 2>/dev/null)
	deviceID=$(printf "${inventoryData}" | xmllint --xpath '/mobile_device/general/id/text()' - 2>/dev/null)
}

updateOS() {
	endpoint="JSSResource/mobiledevicecommands/command/ScheduleOSUpdate/2/id/$deviceID"
	curl -su ${jssUser}:${jssPass} -H "Content-type: text/xml" ${jssURL}${endpoint} -X POST 1>/dev/null
	((count+=1))
	printf "Update scheduled for $serial\n"
}

updateiPads() {
	# Update iPadOS to the latest version and reboot
	getXML
	for serial in ${devices[@]}
	do
		getMobileDeviceInformation
		updateOS
	done
	printf "Updated $count devices\n"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# main

updateiPads

exit 0