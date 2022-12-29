#!/bin/zsh

# Created by Vasean Everett

# Import custom bash functions
source "<PATH/TO/CUSTOM/FUNCTIONS>"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# This script compares the currently logged in user to the currently assigned user and a list of service accounts.  #
# If the logged in user matches neither one of the specified service accounts, or the currently assigned user,	    #
# the inventory record is updated, assigning it to the logged in user.						    #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define Variables

apiPassPhrase="<PASSPHRASE>"
jssUser="<APIUSERNAME>"
jssPass=$(DecryptString "$apiString" "$apiPassPhrase")
endpoint="JSSResource/computers/serialnumber/"

# Account information
serviceAccounts=("<USER1>" "<USER2>" "<USER3>" "<USER4>" "<USER5>")

# Computer information
serial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define functions

checkUsers() {
	# Determine wether the current user is a service account
	serviceAccountFound="false"
	for i in ${serviceAccounts[@]}; do
		if [[ "$i" == "$loggedInUser" ]]; then
			serviceAccountFound="true"
		fi
	done
	
	if  [[ ! "$serviceAccountFound" == "true" ]]; then
		assignedUsername=$(printf $loggedInUser | tr '[:upper:]' '[:lower:]')
	else
		printf "\nPolicy ran on service account \"$loggedInUser\".\n"
		printf "No user was assigned.\n"
		exit 0
	fi
}

checkAssignment() {
	# Determine wether the inventory record in the jss is already properly assigned
	inventoryData=$(curl -X GET -u ${jssUser}:${jssPass} ${jssURL}${endpoint}${serial} -H "accept: application/xml")
	inventoryUsername=$(echo $inventoryData | xmllint --xpath "string(//username)" - | awk '{print tolower($0)}')
	if [[ "$inventoryUsername" == "$assignedUsername" ]]
	then
		printf "Computer is already assigned to \"$inventoryUsername\""
		exit 0
	fi
}

usernameFromLocalAccount() {
	checkUsers
	checkAssignment
	xmlSnippet="<computer><location><username>$assignedUsername</username></location></computer>"
	curl -sku ${jssUser}:${jssPass} ${jssURL}${endpoint}${serial} -X PUT -H "Content-Type: text/xml" -d ${xmlSnippet}
	printf "\n\nAssigned to $assignedUsername\n\n"
	jamf recon
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# main

usernameFromLocalAccount

exit 0
