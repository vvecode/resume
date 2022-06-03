#!/bin/zsh

# Created by Vasean Everett

# Import custom bash functions
source "<PATH/TO/CUSTOM/FUNCTIONS>"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Download and install Postman from a zip and import jamf api collection
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define Variables

url="https://dl.pstmn.io/download/latest/osx"
destination="/Applications/"
applicationName="Postman.app"
outputPath=/tmp/
outputFile="${outputPath}Postman.zip"
uncompressedFile="${outputPath}$applicationName"
application="${destination}$applicationName"
process="Postman"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define functions

importAPI() {
	open "https://app.getpostman.com/run-collection/3f5cc9fc4978cdae78fc"
	sleep 1
	open "postman://app/collections/import/3f5cc9fc4978cdae78fc?referrer=https%3A%2F%2Fapp.getpostman.com%2Frun-collection%2F3f5cc9fc4978cdae78fc#?"
	osascript <<'END'
tell application "Safari"
close current tab of front window without saving
end tell
END
}

downloadPostman(){
	curl -L "${url}" -o "$outputFile"
	open "$outputFile"
	sleep 10
	if [[ -e "$application" ]]; then
		pkill "$process"
		rm -rf "$application"
	fi
	sleep 3
	mv "$uncompressedFile" "$destination"
	xattr -r -d com.apple.quarantine "$application"
	runAsUser open "$application"
	rm "$outputFile"
	sleep 3
	importAPI
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# main

downloadPostman

exit 0