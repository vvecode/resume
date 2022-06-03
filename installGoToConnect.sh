#!/bin/zsh

# Created by Vasean Everett

# Import custom bash functions
source "<PATH/TO/CUSTOM/FUNCTIONS>"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Download and install GoToConnect from a disk image
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define Variables

appName="GoTo.app"
url="https://link.gotoconnect.com/mac"
pathToApp="/Applications/$appName"
dmg="/tmp/GoTo.dmg"
mountPrefix="GoTo"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define functions

installGoToConnect() {
	/usr/bin/curl -L -o ${dmg} ${url}
	hdiutil attach -nobrowse "$dmg"
	volumeName=$(ls /Volumes/ | grep $mountPrefix)
	cp -r "/Volumes/${volumeName}/${appName}" "/Applications/"
	sleep 3
	open "$pathToApp"
	hdiutil detach "/Volumes/$volumeName"
	rm $dmg
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# main

installGoToConnect

exit 0