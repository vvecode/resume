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

# Authentication
requestBearerToken() {
	local endpoint="api/v1/auth/token"
	local response=$(curl -su ${jssUser}:${jssPass} -H "application/json" ${jssURL}${endpoint} -X POST)
	bearerToken=$(echo "$response" | plutil -extract token raw -)
	tokenExpiration=$(echo "$response" | plutil -extract expires raw - | awk -F . '{print $1}')
	tokenExpirationEpoch=$(date -j -f "%Y-%m-%dT%T" "$tokenExpiration" +"%s")
}

checkTokenExpiration() {
	local success="Token generated"
	nowEpochUTC=$(date -j -f "%Y-%m-%dT%T" "$(date -u +"%Y-%m-%dT%T")" +"%s")
	if [[ tokenExpirationEpoch -gt nowEpochUTC ]]
	then
		echo "Token valid until the following epoch time: " "$tokenExpirationEpoch"
	else
		echo "Generating token…"
		requestBearerToken
		checkResult
	fi
}

invalidateToken() {
	local success="Token invalidated"
	local endpoint="api/v1/auth/invalidate-token"
	responseCode=$(curl -w "%{http_code}" -H "Authorization: Bearer ${bearerToken}" ${jssURL}${endpoint} -X POST -s -o /dev/null)
	if [[ ${responseCode} == 204 ]]
	then
		bearerToken=""
		tokenExpirationEpoch="0"
		checkResult
	elif [[ ${responseCode} == 401 ]]
	then
		echo "Token already invalid"
	else
		echo "An unknown error occurred invalidating the token"
	fi
}

# API 2.0
getManagementID () {
	local endpoint="api/v1/computers-inventory-detail/$computerID"
	local record=$(curl -s -H "Authorization: Bearer ${bearerToken}" ${jssURL}${endpoint} -H "application/json" -X GET)
	managementID=$(echo "$record" | grep -e "managementId" | awk '{print $3}' | tr -d '","\n')
	echo "Management ID: $managementID"
}

getDeviceInfo() {
	local endpoint="JSSResource/computers/serialnumber/$serial"
	local record=$(curl -s -H "Authorization: Bearer ${bearerToken}" ${jssURL}${endpoint} -H "application/json" -X GET)
	computerID=$(echo "${record}" | xmllint --xpath '/computer/general/id/text()' - 2>/dev/null)
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
		# macoS 14.0 Sonoma
		14)
			osName="Sonoma"
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
	local endpoint="api/preview/mdm/commands"
	local data='{
	"commandData": {"commandType": "ERASE_DEVICE", "pin": "390390", "obliterationBehavior": "Default"},
	"clientData": [{"managementId": "'"${managementID}"'"}]
}'
	curl -s -H "Authorization: Bearer ${bearerToken}" -H "accept: application/json" -H "content-type: application/json" "${jssURL}${endpoint}" -X POST -d "$data"
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
	checkTokenExpiration
	#	Determine if jss EraseDevice command is supported
	if [[ $archType == "arm64" || "$T2Chip" == "Apple T2 Security Chip" ]] && [[ "$installedOS" =~ ^[1][2,3] ]]
	then
		# EraseDevice command supported
		printf "EraseDevice command supported\n"
		getDeviceInfo
		getManagementID
		eraseDevice
		invalidateToken
	else
		# EraseDevice command not supported
		checkEraseRequirements
	fi
	printf "Architechture: $archType\nHas T2: $T2Chip\nMajor OS: $majorVersion\n"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# main

resetMac

exit 0
