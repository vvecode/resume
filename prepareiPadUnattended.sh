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

wifiProfile="<PATH/TO/CONFIGURATION/PROFILE>"

starttime=$(date +%s)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define functions

editPATH() {
	application=$(ls /Applications | grep "Apple Configurator")
	PATH=$PATH:"/Applications/$application/Contents/MacOS/"
}

setUtilityPath() {
	application=$(ls /Applications | grep "Apple Configurator")
	utilityPath=$(ls /Applications/"$application"/Contents/MacOS/cfgutil)
	cfgutil="${utilityPath}"
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

getMobileDeviceInformation() {
#	serial=$("${cfgutil}" -e $device get serialNumber 2>/dev/null)
	endpoint="JSSResource/mobiledevices/serialnumber/${serial}"
	xml=$(curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint} -X GET)
	assetTag=$(printf "${xml}" | xmllint --xpath '/mobile_device/general/asset_tag/text()' - 2>/dev/null)
	deviceID=$(printf "${xml}" | xmllint --xpath '/mobile_device/general/id/text()' - 2>/dev/null)
}

configureMobileDeviceName() {
	if [[ $isEnrolled -eq 0 ]]
	then
		printf "Configuring device name\n"
		"${cfgutil}" -e $device rename $assetTag 2>/dev/null
		printf "Device name configured: \"$assetTag\"\n"
	else
		printf "Unable to configure the device name because no record was found.\n"
	fi
}

configureNetwork() {
	if [[ ! -e "$wifiProfile" ]]
		then
		tee ${wifiProfile} << Profile
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
			<string>com.apple.wifi.managed.9A9E56C5-33DC-493C-B43E-413DE51E74B4</string>
			<key>PayloadType</key>
			<string>com.apple.wifi.managed</string>
			<key>PayloadUUID</key>
			<string>9A9E56C5-33DC-493C-B43E-413DE51E74B4</string>
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
	<string>FB89CA16-3361-4C7C-4HOUR-ECC488BFF6A5</string>
	<key>PayloadOrganization</key>
	<string>Oak Park Unified School District</string>
	<key>PayloadRemovalDisallowed</key>
	<false/>
	<key>PayloadType</key>
	<string>Configuration</string>
	<key>PayloadUUID</key>
	<string>5E23F1E3-AAC6-4FEB-B41C-437C1D8148F1</string>
	<key>PayloadVersion</key>
	<integer>1</integer>
</dict>
</plist>
Profile
	fi
	"${cfgutil}" -e $device install-profile "$wifiProfile" >/dev/null 2>&1
	printf "Wi-Fi profile installed\n"
}

prepareDevice() {
	printf "Preparing…\n"
	configureNetwork
	"${cfgutil}" -e $device prepare --dep --skip-language --skip-region 2>/dev/null
	printf "iPad $assetTag prepared successfully\n"
}

blankPush() {
	endpoint="JSSResource/mobiledevicecommands/command/BlankPush/${assetTag}/id/${deviceID}"
	curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint} -X POST 1>/dev/null
}

updateInventory() {
	printf "Updating inventory record: "$assetTag"…\n"
	endpoint="JSSResource/mobiledevicecommands/command/UpdateInventory/${assetTag}/id/${deviceID}"
	curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint} -X POST 1>/dev/null
	sleep 3
	blankPush
}

restoreDevice() {
	timer=60
	printf "Restoring…\n"
	"${cfgutil}" -e $device restore 2>/dev/null
	printf "Waiting for device"
	for ((i=60; i>0; i--))
	do
		printf ". "
		sleep 1
	done
	printf "Continuing…\n"
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
	if [[ $attachedDeviceHostname != $assetTag ]]; then
		printf "\nHostname Mismatch: $serial\n\n"
		configureMobileDeviceName
	fi
}

removeCacheFile() {
	rm "$cacheFile"
	printf "Cache file deleted\n"	
}

removeWiFiProfile() {
	rm "$wifiProfile"
	printf "Wi-Fi profile deleted\n"
}

cleanup() {
	printf "Cleaning up…\n"
	removeCacheFile
#	removeWiFiProfile
}

reportStart() {
	startTime=$(date)
	printf "\nStart: $startTime\n\n"
}

reportComplete() {
	completedTime=$(date)
	printf "\nComplete: $completedTime\n"
}

resetDevice() {
	setUtilityPath
	countAttachedDevices
	getAttachedDevices
	for device in "${devices[@]}"
	do
		export attachPID=$$
		cacheFile="/tmp/com.apple.configurator.AttachedDevices.$device.plist"
		if [[ ! -f "$cacheFile" ]]
		then
			touch "$cacheFile"
			printf "$attachPID" >> $cacheFile
			reportStart
			restoreDevice
			verifyEnrollment
			getMobileDeviceInformation
			configureMobileDeviceName
			prepareDevice
			checkMobileDeviceName
			updateInventory
			cleanup
			printLongDuration
			reportComplete
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

resetDevice

exit 0