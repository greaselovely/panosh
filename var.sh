#!/bin/bash

# A collection of variables being sourced from 
# other scripts.  Update this file as needed 
# for paths you prefer
# add-inventory.sh does not use this file, so update it too.

# add to this list any apps / utilities used to check they are installed
required_binaries=("xmllint" "tar" "grep" "awk" "sed" "curl")

# Used to centralize all variables for all PAN scripts
sleep_seconds=5
today=$(date +%m-%d-%Y)
vendor="paloalto"
win="success.txt"
fail="error.txt"
final="$vendor$subfolder.txt"
bounce="${HOME}/$vendor/reboots"
inventory="${HOME}/$vendor/inventory.txt"
dump="${HOME}/$vendor/$subfolder/$today"
rebootlist="rebootlist.txt"
dyn="dynamic_updates"
dyndump="${HOME}/$vendor/$dyn/$today"

# outdated:
# donotinstall="false"
# downloadagain="y"


### use if you have sendmail setup.  Some scripts have it commented out
# emailfrom="From: panosh Admin <no-reply@panosh.local>"
# emailto="To: my-email-address@domain.com"
#	email addresses used in the sendmail functions for notifications
###

info="[i]\t"
alert="[!]\t"
question="[?]\t"

shopt -s nocasematch


function command_exists() {
    command -v "$1" >/dev/null 2>&1
}

function ensure_directory_exists() {
    local dir=$1
    if [ ! -d "$dir" ]
		then
        	mkdir -p "$dir"
    fi
}


# check the array of tools we are using exist.
# update the array with tools that you use above.
for binary in "${required_binaries[@]}"
	do
		if command_exists "$binary"
			then
				:
		else	
				clear
				echo -e "${alert}$binary is not installed. Please install it to continue.\n"
				exit 1
    	fi
done

# Check that our subdirectories exist
ensure_directory_exists "$dump"
ensure_directory_exists "$bounce"



### Inventory / API List ###
if [ ! -e "$inventory" ]
	then 
		# clear
		./add-inventory.sh
fi

perm=$(stat -c "%a" "$inventory" 2>/dev/null)
if [ -z "$perm" ]
	then
		# MacOS bash issue:
		perm=$(stat -f '%Lp' "$inventory")
fi

if [ "$perm" != "600" ]
	then
		chmod 600 "$inventory"
		echo -e "${info}Securing Inventory"
fi
### End Inventory / API List ###