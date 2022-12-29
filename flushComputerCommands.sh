#!/bin/zsh

# Created by Vasean Everett

# Import custom functions
source "<PATH/TO/CUSTOM/FUNCTIONS>"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Clears all pending and failed commands for all computers in the jss
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define Variables

apiPassPhrase="<PASSPHRASE>"
jssUser="<APIUSERNAME>"
jssPass=$(DecryptString "$apiString" "$apiPassPhrase")

# Specify group ID to clear
groupID=000

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define functions

getSerialNumbers() {
	# Get members of specified group
	endpoint="JSSResource/computergroups/id/$groupID"
	xml=$(curl -X GET -u ${jssUser}:${jssPass} ${jssURL}${endpoint} -H "accept: application/xml")
	devices=($(echo "$xml" | xmllint --format - | awk -F'>|<' '/<serial_number>/{print $3}' | sort -n))
}

getDeviceInformation() {
	# Get device id
	endpoint="JSSResource/computers/serialnumber/${serial}"
	inventoryData=$(curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint} -X GET)
	deviceID=($(echo "${inventoryData}" | xmllint --xpath '/computer/general/id/text()' - 2>/dev/null))
}

checkResult() {
	printf "\nChecking result…\n"
	if [[ $? -eq 0 ]]
	then
		printf "Command Issued. Device ID: $deviceID\n"
	else
		printf "An error occurred\n"
	fi
}

flushCommands() {
	endpoint="JSSResource/commandflush/computers/id/${deviceID}/status/Pending+Failed"
	curl -sfku ${jssUser}:${jssPass} -H "content-type: text/xml" ${jssURL}${endpoint} -X DELETE
}

clearManagementCommands() {
	for serial in ${devices[@]}
	do
		getDeviceInformation
		flushCommands
		checkResult
	done
}

main() {
	getSerialNumbers
	getDeviceInformation
	clearManagementCommands
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# main

main

exit 0
