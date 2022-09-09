#!/bin/zsh

# Created by Vasean Everett

# Import custom functions
source "/PATH/TO/CUSTOM/FUNCTIONS"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Compare local user account to a list of management accounts to be kept and
# remove any accounts not listed.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define Variables

localUsers=($(dscl . list /Users | grep -v '_'))

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Define functions

reportUsersToRemove() {
	# Report which accounts are going to be removed
	printf "Report:\n"
	for user in ${toRemove[@]}
	do
		printf "Will remove: $user\n"
	done
}

compareUsers(){
	# List of users to keep
	case "$localUser" in
		"<USER1>");;"<USER2>");;\
		"<USER3>");;"<USER4>");;\
		"<USER5>");;"<USER6>");;\
		"<USER7>");;"<USER8>");;\
		*)
		# Default case. If user is not listed above, it is added to removal array
		toRemove+=($localUser);;
	esac
}

checkUsers() {
	# Compare local users to management accounts to be kept
	printf "Comparing users…\n"
	for localUser in ${localUsers[@]}
	do
		compareUsers
	done
	reportUsersToRemove
}

removeAccounts() {
	# Remove all users not listed in switch case above
	for user in ${toRemove[@]}
	do
		printf "Removing user $user\n"
		sysadminctl -deleteUser "$user"
		printf "User: $user removed\n"
	done
}

main() {
	checkUsers
	removeAccounts
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# main

main

exit 0
