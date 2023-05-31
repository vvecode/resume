#!/bin/zsh

# Created by Vasean Everett

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Suppress "Agree to license" and "Get Started" button for Apple Configurator 2
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define Variables

# Get the current logged in user
loggedInUser=$(ls -l /dev/console | cut -d " " -f 4)

# Get the ID of the current logged in user
uid=$(id -u "$loggedInUser")

bundleIdentifier="com.apple.configurator.ui"
application=$(mdfind kMDItemCFBundleIdentifier = "$bundleIdentifier")
licenseVersion=$(defaults read "$application"/Contents/Info.plist ACULicenseVersion)
configuratorPLIST="/Users/$loggedInUser/Library/Containers/com.apple.configurator.ui/Data/Library/Preferences/com.apple.configurator.ui.plist"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define functions

# Run a command as the current logged in user
runAsUser() {
	if [[ "$loggedInUser" != "loginwindow" ]]
	then
		launchctl asuser "$uid" sudo -u "$loggedInUser" "$@"
	else
		echo "no user logged in"
	fi
}

# Launch Configurator to create plist
configuratorFirstRun() {
	printf "Launching Configurator…\n"
	runAsUser open -gja "$application"
	printf "Application launched\n\n"
	pkill -x "Apple Configurator"
}

# Check exit code of last command
checkResult() {
	if [[ $? -eq 0 ]]
	then
		printf "$success\n\n"
	else
		printf "$error\n\n"
	fi
}

agreeToLicense() {
	success="License agreement suppressed"
	error="An error occurred. Unable to suppress license agreement"
	printf "Suppressing license agreement…\n"
	runAsUser defaults write ${configuratorPLIST} LastAcceptedConfiguratorLicenseVersion ${licenseVersion}
	checkResult
}

suppressGetStarted() {
	success="\"Get Started\" button suppressed"
	error="An error occurred. Unable to supress \"Get Started\" button"
	printf "Suppressing \"Get Started\" button…\n"
	runAsUser defaults write ${configuratorPLIST} LastWecomeVersionShown 1
	checkResult
}

suppressFirstRunPrompts() {
	configuratorFirstRun
	agreeToLicense
	suppressGetStarted
	runAsUser open "$application"
}
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# main

suppressFirstRunPrompts

exit 0
