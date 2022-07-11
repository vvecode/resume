#!/bin/zsh

# Created by Vasean Everett

# Import custom bash functions
source "<PATH/TO/CUSTOM/FUNCTIONS>"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Creates a configuration profile that connects to Wi-Fi, signs the profile
# using the JSS built in signing certificate so it shows "Verfied" and then
# installs the profile on the connected iPad.
#
# * Note: This script requires user interaction on both the Mac and iPad.
# 
# First: The user is prompted for their login credentials in order to sign
# the configuration profile.
#
# Second: The user must install the profile from "Settings" on the iPad by
# navigating to "Settings" -> "Profile Downloaded" -> "Install" -> "Install"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define Variables

apiPassPhrase="<PASSPHRASE>"
jssUser="<APIUSERNAME>"
jssPass=$(DecryptString "$apiString" "$apiPassPhrase")

unsignedProfile="/tmp/Unsigned Profile.mobileconfig"
wifiProfile="/tmp/Recovery Wi-Fi.mobileconfig"

certCN="Profile Signing Certificate"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define functions

setUtilityPath() {
	application=$(ls /Applications | grep "Apple Configurator")
	utilityPath=$(ls /Applications/"$application"/Contents/MacOS/cfgutil)
	cfgutil="${utilityPath}"
	device=$("${cfgutil}" get ECID 2>/dev/null)
}

createProfile() {
	tee "${unsignedProfile}" << Profile
	<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>DurationUntilRemoval</key>
	<integer>86400</integer>
	<key>PayloadContent</key>
	<array>
		<dict>
			<key>AutoJoin</key>
			<true/>
			<key>CaptiveBypass</key>
			<false/>
			<key>DisableAssociationMACRandomization</key>
			<false/>
			<key>EncryptionType</key>
			<string>WPA</string>
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
			<string>com.apple.wifi.managed.1F452F4A-4756-47F9-B82C-A82E3739B7E3</string>
			<key>PayloadType</key>
			<string>com.apple.wifi.managed</string>
			<key>PayloadUUID</key>
			<string>1F452F4A-4756-47F9-B82C-A82E3739B7E3</string>
			<key>PayloadVersion</key>
			<integer>1</integer>
			<key>ProxyType</key>
			<string>None</string>
			<key>SSID_STR</key>
			<string><SSID></string>
		</dict>
	</array>
	<key>PayloadDisplayName</key>
	<string><SSID></string>
	<key>PayloadIdentifier</key>
	<string>8DAA5F49-4A32-428F-994D-F7969DAB8E39</string>
	<key>PayloadOrganization</key>
	<string><Organization Name></string>
	<key>PayloadRemovalDisallowed</key>
	<false/>
	<key>PayloadType</key>
	<string>Configuration</string>
	<key>PayloadUUID</key>
	<string>98673EA9-7CA5-416C-8241-38BA4479A6FE</string>
	<key>PayloadVersion</key>
	<integer>1</integer>
</dict>
</plist>
Profile
}

signProfile() {
	/usr/bin/security cms -S -N "${certCN}" -i "${unsignedProfile}" -o "${wifiProfile}"
}

installProfile() {
	"${cfgutil}" -e ${device} install-profile "${wifiProfile}" >/dev/null 2>&1
	printf "Wi-Fi profile installed\n"
}

deleteProfile() {
	rm "$wifiProfile", "$unsignedProfile"
	printf "Wi-Fi profile deleted\n"
}

installWi-FiProfile() {
	setUtilityPath
	createProfile
	signProfile
	installProfile
	deleteProfile
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# main

installWi-FiProfile

exit 0