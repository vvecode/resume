#!/bin/zsh

# Created by Vasean Everett

# Import custom functions
source "<PATH/TO/CUSTOM/FUNCTIONS>"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for macOS installer. If found, run eraseinstall. If the installer
# is missing, download it, then run eraseinstall.
#
# Note:
#	Computer must either have an Intel T2 chip or Apple Silicon processor
#	AND
#	Running macOS Monterey or higher to use jss command
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define Variables

jssUser="<APIUSERNAME>"
apiPassPhrase="<PASSPHRASE>"
jssPass=$(DecryptString "$apiString" "$apiPassPhrase")
serial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
password=$(DecryptString "$5" "$6")
installedOS=$(sw_vers | awk 'FNR==2{print $2}')
majorVersion="${installedOS:0:2}"
T2Chip=$(/usr/sbin/system_profiler SPiBridgeDataType | awk -F': ' '/Model Name:/{print $NF}')

passcode="<PASSCODE>"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define functions

getDeviceInfo() {
	# Retrieve device inventory information
	endpoint="JSSResource/computers/serialnumber/"
	xml=$(curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint}${serial} -X GET)
	computerID=$(printf "${xml}" | xmllint --xpath '/computer/general/id/text()' - 2>/dev/null)
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

checkForT2() {
	printf "Checking for T2 chip\n"
	if [[ -n $T2Chip && $T2Chip ==  *"T2"* ]]
	then
		printf "T2 chip present\n"
		hasT2="true"
	else
		printf "T2 chip not present\n"
		hasT2="false"
	fi
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

downloadInstaller() {
	softwareupdate --fetch-full-installer --full-installer-version ${installedOS}
}

eraseInstall() {
#	Run eraseinstall command locally from macOS installer
	printf "Erasing macOS…\n"
	echo ${password} | "/Applications/Install macOS $osName.app/Contents/Resources/startosinstall" --user "${4}" --stdinpass --forcequitapps --rebootdelay 0 --nointeraction --agreetolicense --forcequitapps --eraseinstall --newvolumename "Macintosh HD"
}

localErase() {
#	Check for installer and download if missing then erase machine
	if [[ $installerPresent == "true" ]]
	then
		eraseInstall
	else
		printf "Missing installer. Downloading\n"
		downloadInstaller
		printf "Installer downloaded\n"
		eraseInstall
	fi
}

eraseDevice() {
#	Create EraseDevice command from jss
	printf "Issuing EraseDevice command from jss…\n"
	xmlSnippet="<computer_command><general><command>EraseDevice</command><passcode>$passcode</passcode></general><computers><computer><id>$computerID</id></computer></computers></computer_command>"
	endpoint="JSSResource/computercommands/command/EraseDevice/"
	curl -sku ${jssUser}:${jssPass} ${jssURL}${endpoint}${serial} -X POST -H "Content-Type: text/xml" -d ${xmlSnippet} 2>&1
	printf "EraseDevice command issued\nPasscode: $passcode\n"
}

resetMac() {
#	Determine if jss EraseDevice command is supported
	checkForT2
	if [[ $archType == "arm64" || $hasT2 == "true" && $majorVersion > 11 ]]
	then
#		EraseDevice command supported
		printf "EraseDevice command supported\n"
		getDeviceInfo
		eraseDevice
	else
#		EraseDevice command not supported
		printf "EraseDevice command not supported\n"
		checkForInstaller
		localErase
	fi
}

resetMac() {
	setOSName
	resetMac
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# main

resetMac

exit 0