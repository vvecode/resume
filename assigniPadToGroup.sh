#!/bin/zsh

# Created by Vasean Everett

# Import custom bash functions
source "<PATH/TO/CUSTOM/FUNCTIONS>"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Search for an iPad by its hostname and return the serian number, then assign
# the device to a mobile device group by group id
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define Variables

apiPassPhrase="<PASSPHRASE>"
jssUser="<APIUSERNAME>"
jssPass=$(DecryptString "$apiString" "$apiPassPhrase")

groupID="116"
devices=("HOSTNAME1" "HOSTNAME2" "HOSTNAME3" "HOSTNAME4")

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define functions

getiPadSerialNumber() {
	endpoint="JSSResource/mobiledevices/name/"
	serialNumber=$(curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint}${device} -X GET | xmllint --xpath '/mobile_device/general/serial_number/text()' -)
}

assigniPadToGroup() {
		endpoint="JSSResource/mobiledevicegroups/id/$groupID"
		assignmentXML="<mobile_device_group><mobile_device_additions><mobile_device><serial_number>${serialNumber}</serial_number></mobile_device></mobile_device_additions></mobile_device_group>"
		curl -su ${jssUser}:${jssPass} -H "content-type: application/xml" ${jssURL}${endpoint} -X PUT -d "$assignmentXML"
}

getiPadAndAssign() {
	for device in ${devices[@]}
		do
			getiPadSerialNumber
			assigniPadToGroup
	done
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# main

getiPadAndAssign

exit 0