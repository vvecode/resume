#!/bin/zsh

# Created by Vasean Everett

# Import custom bash functions
source "<PATH/TO/CUSTOM/FUNCTIONS>"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Delete all classes from the jss
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define Variables

apiPassPhrase="<PASSPHRASE>"
jssUser="<APIUSERNAME>"
jssPass=$(DecryptString "$apiString" "$apiPassPhrase")

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define functions

deleteClasses() {
	endpoint="JSSResource/classes"
	classes=$(curl -X GET -u ${jssUser}:${jssPass} ${jssURL}${endpoint} -H "accept: application/xml" | xmllint --format - | awk -F '[<>]' '/<id>/{print $3}')
	for id in $classes; do
		curl -su $jssUser:"$jssPass" -H "Content-Type: text/xml" ${jssURL}${endpoint}/id/${id} -X DELETE
	done
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# main

deleteClasses

exit 0