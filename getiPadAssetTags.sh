#!/bin/zsh

# Created by Vasean Everett

# Import custom bash functions
source "<PATH/TO/CUSTOM/FUNCTIONS>"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Read from csv to lookup and output the asset tags for specified devices
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define Variables

apiPassPhrase="<PASSPHRASE>"
jssUser="<APIUSERNAME>"
jssPass=$(DecryptString "$apiString" "$apiPassPhrase")

inputFile="/Users/$loggedInUser/Input Files/Device Information.csv"
outputFile="/Users/$loggedInUser/Desktop/Serial Numbers & Asset Tags.csv"
missingDeviceFile="/Users/$loggedInUser/Desktop/Missing Devices.csv"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define functions

cleanUpOldFile() {
	# Delete the existing file if it exists
	if [[ -e "$outputFile" ]]; then
		runAsUser rm "$outputFile"
		printf "Removed old output file\n"
	fi
}

createMissingDeviceFile() {
	# Create Missing Devices.csv
	printf "UDID,Name,Serial Number\n" >> "$missingDeviceFile"
	printf "Created Missing Devices.csv\n"
}

removeMissingDeviceFile() {
	# Remove Missing Devices.csv
	runAsUser rm "$missingDeviceFile"
	printf "Removed old Missing Device.csv file\n"
}

prepareMissingDeviceFile() {
	# Check wether the file exists. If so, delete it and create a new, empty file, otherwise create it
	if [[ ! -f "$missingDeviceFile" ]]; then
		createMissingDeviceFile
	elif [[ -e "$missingDeviceFile" ]]; then
		removeMissingDeviceFile
		createMissingDeviceFile
	fi
}

gatherMissingDevices() {
	# If an asset tag is missing, export the serial number to a csv
		if [[ ! -z "${missingDevices[@]}" ]]; then
			prepareMissingDeviceFile
		for serial in ${missingDevices[@]}
		do
			printf "$serial was not found\n"
			printf ",,$serial\n" >> "$missingDeviceFile"
		done
	fi
}

getMobileDeviceInformation() {
		# 3. Poll the JSS for the asset tag and device id
		endpoint="JSSResource/mobiledevices/serialnumber/${serial}"
		xml=$(curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint} -X GET)
		assetTag=$(printf "${xml}" | xmllint --xpath '/mobile_device/general/asset_tag/text()' - 2>/dev/null)
		deviceID=$(printf "${xml}" | xmllint --xpath '/mobile_device/general/id/text()' - 2>/dev/null)
}

setDeviceName() {
	# Set device name to its Asset Tag
	endpoint="JSSResource/mobiledevicecommands/command/DeviceName/${assetTag}/id/${deviceID}"
	curl -su ${jssUser}:${jssPass} -H "accept: text/xml" ${jssURL}${endpoint} -X POST 1>/dev/null
	printf "Set device \"$serial\" name to \"$assetTag\"\n"
}

formatSerial() {
	#	Remove new-line character from the current record
	serial=$(echo $serial | tr -d "\n")
}

getiPadAssetTags() {
	# 1. Read the device serial number from each record
	# 2. Format the serial number by removing new-line
	# 3. Gather asset tag and device id of the device
	# 4. If a device is found in the JSS return the serial number and asset tag of the device
	#    If not, print an error that the device was not found
	cleanUpOldFile
	oldIFS=$IFS
	IFS=","
	# 1. Read the device serial number from each record
	while IFS=, read -r udid name serial
	do
		if [[ "$serial" != "Serial Number" ]]; then
			# 2. Format the serial number by removing new-line
			formatSerial
			# 3. Poll the JSS for the asset tag and device id
			getMobileDeviceInformation
			# 4. If so, return the serial number and asset tag of the device
				if [[ -z "$assetTag" ]]; then
					if [[ ${serial} != *"Serial"* ]];then
					missingDevices+=($serial)
					fi
				else
					echo "$serial, $assetTag" >> "$outputFile"
					setDeviceName
				fi
		fi
	done < "$inputFile"
	IFS=$oldIFS
	
	gatherMissingDevices
	
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# main

getiPadAssetTags

exit 0