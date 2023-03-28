#!/bin/zsh

# Created by Vasean Everett

# Import custom bash functions
source "<PATH/TO/CUSTOM/FUNCTIONS>"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Unattended restore of connected iPad upon attachment to the system. Once
# restored, connect to Wi-Fi and re-enroll in the JSS, gathering device
# information and setting the hostname to the devices asset tag.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define Variables

apiPassPhrase="<PASSPHRASE>"
jssUser="<APIUSERNAME>"
jssPass=$(DecryptString "$apiString" "$apiPassPhrase")

bundleIdentifier="com.apple.configurator.ui"

wifiProfile="<PATH/TO/CONFIGURATION/PROFILE>"

starttime=$(date +%s)
passcode="123456"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define functions

editPATH() {
	application=$(mdfind kMDItemCFBundleIdentifier = "$bundleIdentifier")
	PATH=$PATH:"/Applications/$application/Contents/MacOS/"
}

setUtilityPath() {
	cfgutil="$application/Contents/MacOS/cfgutil"
}

getComputerInformation() {
	computerSerial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
	endpoint="JSSResource/computers/serialnumber/$computerSerial"
	xml=$(curl -X GET -u ${jssUser}:${jssPass} ${jssURL}${endpoint} -H "accept: application/xml")
	computerBuilding=$(echo $xml | xmllint --xpath "string(//building)" -)
}

assignToComputerBuilding() {
	printf "Assigning device $serial to \"$computerBuilding\"\n"
	endpoint="JSSResource/mobiledevices/id/$deviceID"
	xmlSnippet="<mobile_device><location><building>$computerBuilding</building></location></mobile_device>"
	curl -sku ${jssUser}:${jssPass} ${jssURL}${endpoint} -X PUT -H Content-Type: text/xml -d ${xmlSnippet} 2>&1
	printf "iPad: $serial now assigned to \"$computerBuilding\"\n"
}

checkForConfigurator() {
	printf "Checking for Apple Configurator…\n"
	service='Apple Configurator'
	if pgrep -xq -- "${service}"
	then
		printf "Apple Configurator is already running\n\n"
	else
		printf "Apple Configurator is not running.\nLaunching…\n\n"
		open "$application"
		sleep 2
		printf "Apple Configurator is now running\n\n"
	fi
}

countAttachedDevices() {
	attachedDevices=($("${cfgutil}" -f list 2>/dev/null | awk '{print $4}'))
	for i in ${attachedDevices[@]}
	do
		((attachedDeviceCount+=1))
	done
}

getAttachedDevices() {
	# Get the ECID of all connected mobile devices
	printf "Checking for attached devices…\n"
	if [[ -z "$attachedDeviceCount" ]]
	then
		printf "No devices connected\n"
		exit 1
	elif [[ "$attachedDeviceCount" == 1 ]]
	then
		devices+=($("${cfgutil}" -f get ECID 2>/dev/null))
		printf "One device connected\n$attachedDeviceCount\n"
	else
		devices+=($("${cfgutil}" -f get ECID 2>/dev/null | awk '{print $4}'))
		printf "$attachedDeviceCount devices connected\n"
	fi
}

correctECID() {
	printf "Correcting ECID…\n"
	device=${device:0:${#device}-(($n-16))}
	printf "ECID Corrected: $device\n"
}

checkECID() {
	printf "Checking ECID: $device\n"
	n=$(echo $device | awk '{print length}')
	if [[ $n -gt 16 ]]
	then
		printf "Malformed ECID: $device\n"
		correctECID
	fi
}

getMobileDeviceInformation() {
	checkECID
	serial=$("${cfgutil}" -e $device get serialNumber 2>/dev/null)
	endpoint="JSSResource/mobiledevices/serialnumber/${serial}"
	xml=$(curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint} -X GET)
	deviceID=$(printf "${xml}" | xmllint --xpath '/mobile_device/general/id/text()' - 2>/dev/null)
}

configureMobileDeviceName() {
	if [[ $isEnrolled -eq 0 ]]
	then
		printf "Configuring device name\n"
		"${cfgutil}" -e $device rename $serial 2>/dev/null
		printf "Device name set to serial: \"$serial\"\n"
	else
		printf "Unable to configure the device name because no record was found.\n"
	fi
}

createProfile() {
	tee "${wifiProfile}" << Profile
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>DurationUntilRemoval</key>
	<integer>14400</integer>
	<key>PayloadContent</key>
	<array>
		<dict>
			<key>AutoJoin</key>
			<true/>
			<key>CaptiveBypass</key>
			<false/>
			<key>EncryptionType</key>
			<string>WPA2</string>
			<key>HIDDEN_NETWORK</key>
			<false/>
			<key>IsHotspot</key>
			<false/>
			<key>Password</key>
			<string><PASSWORD></string>
			<key>PayloadDescription</key>
			<string>Configures Wi-Fi settings</string>
			<key>PayloadDisplayName</key>
			<string>Wi-Fi</string>
			<key>PayloadIdentifier</key>
			<string>com.apple.wifi.managed.BE86367E-FBB1-49B2-B8BA-432B222245FD</string>
			<key>PayloadType</key>
			<string>com.apple.wifi.managed</string>
			<key>PayloadUUID</key>
			<string>BE86367E-FBB1-49B2-B8BA-432B222245FD</string>
			<key>PayloadVersion</key>
				<integer>1</integer>
			<key>ProxyType</key>
			<string>None</string>
			<key>SSID_STR</key>
			<string><SSID></string>
		</dict>
	</array>
	<key>PayloadDescription</key>
	<string>Onboarding profile that connects to management network for 4 hours.</string>
	<key>PayloadDisplayName</key>
	<string>Onboarding 4hr</string>
	<key>PayloadIdentifier</key>
	<string>E1373819-F168-4128-B982-2D152F4EF4D5</string>
	<key>PayloadOrganization</key>
	<string>UCLA Library</string>
	<key>PayloadRemovalDisallowed</key>
	<false/>
	<key>PayloadType</key>
	<string>Configuration</string>
	<key>PayloadUUID</key>
	<string>633DF911-C6F6-4466-B22A-ABD234EB6F31</string>
	<key>PayloadVersion</key>
	<integer>1</integer>
</dict>
</plist>
Profile
}

checkForProfile() {
	if [[ ! -e ${wifiProfile} ]]
	then
		createProfile
	fi
}

installProfile() {
	checkForProfile
	printf "Installing Wi-Fi profile\n"
	"${cfgutil}" -e ${device} install-profile "${wifiProfile}" >/dev/null 2>&1
	printf "Profile installed\n"
}

prepareDevice() {
	printf "Preparing…\n"
	installProfile
	"${cfgutil}" -e $device prepare --dep --skip-language --skip-region 2>/dev/null
	printf "iPad $serial prepared successfully\n"
}

blankPush() {
	endpoint="JSSResource/mobiledevicecommands/command/BlankPush/${hostname}/id/${deviceID}"
	curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint} -X POST 1>/dev/null
}

updateInventory() {
	printf "Updating inventory record: "$serial"…\n"
	endpoint="JSSResource/mobiledevicecommands/command/UpdateInventory/${hostname}/id/${deviceID}"
	curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint} -X POST 1>/dev/null
	sleep 3
	blankPush
}

getBootedState(){
	bootedState=$("${cfgutil}" -e $device get bootedState)
	printf "Booted State: $bootedState\n"
}

waitForDevice() {
	if [[ $dot -lt 10 ]]
	then
		printf ". "
		((dot+=1))
	else
		printf "\n"
		((dot=0))
	fi
	sleep 1
}

restoreDevice() {
	timer=90
	printf "Restoring…\n"
	"${cfgutil}" -e $device restore 2>/dev/null
	printf "Waiting for device\n"
	for ((i=$timer; i>0; i--))
	do
		waitForDevice
	done
	printf "\nContinuing…\n"
}

verifyEnrollment() {
	serial=$("${cfgutil}" -e $device get serialNumber 2>/dev/null)
	endpoint="JSSResource/mobiledevices/serialnumber/${serial}"
	xml=$(curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint} -X GET)
	jssSerial=$(printf "${xml}" | xmllint --xpath '/mobile_device/general/serial_number/text()' - 2>/dev/null)
	if [[ -z $jssSerial ]]
	then
		# Device is not enrolled
		printf "The JSS has no record of the device $serial\n"
		isEnrolled=1
		printf "Enrolling device: $serial\n"
		prepareDevice
		isEnrolled=0
		getMobileDeviceInformation
	else
		printf "Record found: Serial: $serial\nJSS Serial: $jssSerial\n"
		isEnrolled=0
	fi
}

checkMobileDeviceName() {
	attachedDeviceHostname=$("${cfgutil}" -e $device get name 2>/dev/null)
	if [[ $attachedDeviceHostname != $serial ]]
	then
		printf "\nHostname Mismatch: $serial\n\n"
		configureMobileDeviceName
	fi
}

removeCacheFile() {
	rm "$cacheFile"
	printf "Cache file deleted\n"	
}

cleanup() {
	printf "Cleaning up…\n"
	removeCacheFile
}

reportStart() {
	startTime=$(date)
	printf "\nStart: $startTime\n\n"
}

reportComplete() {
	completedTime=$(date)
	printf "\nComplete: $completedTime\n"
}

shutDownDevice() {
	printf "Shutting down device…\n"
	endpoint="JSSResource/mobiledevicecommands/command/ShutDownDevice/id/$deviceID"
	curl -su ${jssUser}:${jssPass} -H "Content-type: text/xml" ${jssURL}${endpoint} -X POST 1> /dev/null
	printf "Command issued to shutdown device\n"
}

createCacheFile() {
	touch "$cacheFile"
	printf "$attachPID" >> $cacheFile
}

configureiPad() {
	createCacheFile
	reportStart
	restoreDevice
	verifyEnrollment
	getMobileDeviceInformation
	assignToComputerBuilding
	configureMobileDeviceName
	prepareDevice
	checkMobileDeviceName
	updateInventory
	cleanup
	shutDownDevice
	printLongDuration
	reportComplete
}

resetDevices() {
	editPATH
	setUtilityPath
	getComputerInformation
	checkForConfigurator
	countAttachedDevices
	getAttachedDevices
	for device in "${devices[@]}"
	do
		checkECID
		export attachPID=$$
		cacheFile="/tmp/com.apple.configurator.AttachedDevices.$device.plist"
		if [[ ! -f "$cacheFile" ]]
		then
			configureiPad
		else
			if [[ "$attachPID" == $(cat "$cacheFile") ]]
			then
				printf "PID Match - Continuing…\n"
		else
			printf "PID Mis-Match - Do Nothing…\n"
		fi
	fi
	done
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# main

resetDevices

exit 0
