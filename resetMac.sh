#!/bin/zsh

# Created by Vasean Everett

# Import custom functions
source "<PATH/TO/CUSTOM/FUNCTIONS>"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quick erase macOS Ventura devices that support it. For devices that don't
# support quick erase, check for the macOS full installer and use it to run
# eraseinstall. If the installer is missing, download it, then run eraseinstall.
#
# Note:
# Computer must either have an Intel T2 chip or Apple Silicon processor
# AND
# Running macOS Monterey or higher to use jss command
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define Variables

jssUser="<APIUSERNAME>"
apiPassPhrase="<PASSPHRASE>"
jssPass=$(DecryptString "$apiString" "$apiPassPhrase")
serial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
highestSupportedOS=$(softwareupdate --list-full-installers | awk 'NR==3 {print substr($6, 1, length($6)-1)}')
installedOS=$(sw_vers | awk 'FNR==2{print $2}')
majorVersion="${installedOS:0:2}"
T2Chip=$(/usr/sbin/system_profiler SPiBridgeDataType | awk -F': ' '/Model Name:/{print $NF}')

passcode="<PASSCODE>"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define functions

getDeviceInfo() {
	# Retrieve device inventory information
	printf "Gathering device information from the jss…\nSerial: $serial\n"
	endpoint="JSSResource/computers/serialnumber/"
	xml=$(curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint}${serial} -X GET)
	computerID=$(echo "${xml}" | xmllint --xpath '/computer/general/id/text()' - 2>/dev/null)
	printf "Computer ID: $computerID\n"
}

setOSName(){
	case "$majorVersion" in
		# macOS 11.0 Big Sur
		11)
			osName="Big Sur"
		;;
		# macOS 12.0 Monterey
		12)
			osName="Monterey"
		;;
		# macoS 13.0 Ventura
		13)
			osName="Ventura"
		;;
		*)
			osName="Not supported"
		;;
	esac
}

checkForInstaller() {
	if [[ -e "/Applications/Install macOS $osName.app" ]]
	then
		installerPresent="true"
		printf "$osName installer found\n"
	else
		installerPresent="false"
		printf "$osName installer not found\n"
	fi
}

downloadInstallerAlert() {
	runAsUser osascript -e 'set theDialogText to "Downloading macOS Installer

macOS '"$osName"' must be downloaded before the erase process can begin.
Click \"Okay\" to begin the download.

* Please note: It may take ~45min before the erase process is complete."
	display dialog theDialogText buttons {"Okay"} default button "Okay" with icon caution giving up after 60
	--> Result: {{button returned:"Okay"}'
}

downloadInstaller() {
	caffeinate -disu softwareupdate --fetch-full-installer --full-installer-version ${highestSupportedOS}
}

eraseInstall() {
	printf "Erasing macOS…\n"
	echo ${password} | caffeinate -disu "/Applications/Install macOS $osName.app/Contents/Resources/startosinstall" --user "${4}" --stdinpass --forcequitapps --rebootdelay 0 --nointeraction --agreetolicense --forcequitapps --eraseinstall --newvolumename "Macintosh HD"
}

localEraseAlert() {
	runAsUser osascript -e 'set theDialogText to "Slow Erase
This computer will take ~20 min or more to be erased"
	display dialog theDialogText buttons {"Okay"} default button "Okay" with icon caution giving up after 60
	--> Result: {{button returned:"Okay"}'
}

localErase() {
#	Check for installer and download if missing then erase machine
	localEraseAlert
	if [[ $installerPresent == "true" ]]
	then
		eraseInstall
	else
		printf "Missing installer. Downloading…\n"
		downloadInstallerAlert
		downloadInstaller
		printf "Installer downloaded\n"
	fi
}

eraseDevice() {
#	Create EraseDevice command from jss
	printf "Issuing EraseDevice command from jss…\n\n"
	xmlSnippet="<computer_command><general><command>EraseDevice</command><passcode>$passcode</passcode></general><computers><computer><id>$computerID</id></computer></computers></computer_command>"
	endpoint="JSSResource/computercommands/command/EraseDevice/passcode/$passcode/id/$computerID"
	curl -sku ${jssUser}:${jssPass} ${jssURL}${endpoint}${serial} -X POST -H "Content-Type: text/xml" -d ${xmlSnippet} 2>&1
	printf "\n\nEraseDevice command issued\nPasscode: $passcode\n"
}

quickEraseNotSupportedAlert()  {
	quickEraseSupported=1
	runAsUser osascript -e 'set theAlertText to "Quick Erase\nNot Supported\n"
set theAlertMessage to "Please set aside to be brought up to Powell 390 to be manually reset"
display alert theAlertText message theAlertMessage' >/dev/null 2>&1
	printf "Exiting…\n"
}

checkOSRequirement() {
	printf "Checking OS…\n"
	if [[ "$osName" != "Not supported" ]]
	then
		printf "macOS $osName supported\n\n"
	else
		printf "OS Not supported\n\n"
		quickEraseNotSupportedAlert
		exit 101
	fi
}

checkHardwareRequirement() {
	printf "Checking hardware…\n"
	if [[ "$archType" == "arm64" || "$T2Chip" == "Apple T2 Security Chip" ]]
	then
		printf "Hardware supported\n\n"
	else
		printf "Hardware does not meet requirements\nEraseDevice command not supported\n\n"
		checkForInstaller
		localErase
		eraseInstall
	fi
}

checkEraseRequirements() {
	setOSName
	checkOSRequirement
	checkHardwareRequirement
}

resetMac() {
#	Determine if jss EraseDevice command is supported
	if [[ $archType == "arm64" || "$T2Chip" == "Apple T2 Security Chip" ]] && [[ "$installedOS" =~ ^[1][2,3] ]]
	then
#		EraseDevice command supported
		printf "EraseDevice command supported\n"
		getDeviceInfo
		eraseDevice
	else
		checkEraseRequirements
	fi
	printf "Architechture: $archType\nHas T2: $T2Chip\nMajor OS: $majorVersion\n"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# main

resetMac

exit 0
