#!/bin/bash

# Creates the inventory list of firewalls when it doesn't exist,
# which will be the case when you first run any script.  It will 
# ask you for the friendly name that you want to call the firewall
# (I usually use the actual hostname of the firewall), the IP 
# address (that is accessible for management), the management 
# TCP port (by default is 443, but if you have GlobalProtect 
# running, it is changed to 4443 in the case of managing the 
# firewall from an external interface), username, password.   
# It attempts to reach the firewall, generate and retrieve the
# API key.  If it is successful, it will store most of that
# info (minus username and password) in the inventory.txt 
# file for use later.  Obviously this file becomes highly 
# sensitive once this info is kept in it.  We also check it
# everytime a script is running that perms are 600.  Please ensure your 
# firewall(s) are locked down for management on known good IP's, 
# not just wide open to the inet.  An idea that is floating in 
# my head is to encrypt or minimally encode the txt file or 
# even just encode the API key, but for now this is what we have.

# This file does not use var.sh so you'll have to modify this 
# script as well for any path changes you want.

# This file can't use var.sh since it creates a loop.
sleep_seconds=5
today=$(date +%m-%d-%Y)
vendor="paloalto"
win="success.txt"
fail="error.txt"
subfolder="add_inventory"
final="$vendor$subfolder.txt"
bounce="${HOME}/$vendor/reboots"
inventory="${HOME}/$vendor/inventory.txt"
dump="${HOME}/$vendor/$subfolder/$today"

info="[i]\t"
alert="[!]\t"
question="[?]\t"

shopt -s nocasematch

required_binaries=("xmllint" "tar" "grep" "awk" "sed" "curl")

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
				# clear
				echo -e "${alert}$binary is not installed. Please install it to continue.\n"
				exit 1
    	fi
done


# Check that our subdirectories exist
ensure_directory_exists "$dump"



### Inventory / API List ###
if [ ! -e "$inventory" ]
	then 
		# clear
		echo -e "\n${alert}We need to create an inventory list!\n${info}Please provide firewall credentials below.\n"
fi

function get_api_key() {
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	apiurl="https://$ip:$port/api/?type=keygen"
	echo
	curl -X POST -d "user=$username&password=$password" -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"
	key=$(xmllint --xpath "string(//key/text())" "$file_name")
}

function show_system_info() {
	file_name="$dump/$inv_name.$FUNCNAME.xml"
	apiaction="api/?&type=op&cmd="
	apixpath=""
	apielement="<show><system><info></info></system></show>"
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	curl -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"	
	serial_number=$(xmllint --xpath "string(//serial/text())" "$file_name")
	hostname=$(xmllint --xpath "string(//devicename/text())" "$file_name")
	model_number=$(xmllint --xpath "string(//model/text())" "$file_name")
}

function error_check(){
	error=$(xmllint --xpath "string(//msg/text())" "$file_name" 2>/dev/null)
}

case "$1" in
  help|--help|-h)
		echo -e "$0 <hostname> <ip addr> <port> <username> [enter]"  
		echo 
		echo -e "$0 FRWL-NAME-01 1.2.3.4 443 admin [enter]" 
		echo 
		echo -e "You'll be prompted for the password "
		echo
		exit 0
    ;;
  *)
    :
    ;;
esac



if [ "$1" ]
	then tempname="$1"
		ip="$2"
		port="$3"
		username="$4"
		if [ -z "$4" ]
			then 
			echo -e "\n\n${question}Here's How To Use Me:\n"
			"$0" help
			exit 0
		fi
		read -s -p " Password: " temppassword
	else 
		read -p " Hostname : " inv_name
		read -p " IP Address : " ip
		default_value="443"
		read -p " Port Number [$default_value] : " port
		port=${port:-$default_value}
		default_value="admin"
		read -p " Username [admin] : " username
		username=${username:-$default_value}
		read -s -p " Password: " password
fi

inv_name=$(tr "[:lower:]" "[:upper:]" <<< $inv_name)

#function calls
get_api_key
error_check


if [ "$error" ]
	then
		echo
		echo -e "${alert}$error"
		echo -e "${info}We sent : $apiurl "
		exit 0
fi

echo -ne "\n${question}Do you want to add to inventory? "
default_value="y"
read -p "(y/n) [$default_value]: " confirm
confirm=${confirm:-$default_value}

if [ "$confirm" != "y" ];
	then 
		echo -e "${info}OK.  Here's your API key:"
		echo -e "${info}$key"
		exit
	elif grep -qi "\_$ip\_" "$inventory"
				then
					echo -e "${alert}${ip} is already in inventory."
	else 
		echo -e "${info}Checking to see if it is accessible"
		show_system_info
		if [ $hostname ]
			then
				echo -e "${inv_name}_${ip}_${port}_${key}" >> "$inventory"
				echo -e "${info}$hostname\t$model_number\t$serial_number\n\n"
		else
				echo -e "${alert}${inv_name} doesn't appear to be accessible."
		fi
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
		echo -e "${alert}Securing Inventory"
fi
### End Inventory / API List ###


#cleanup
# rm -rf "$dump"
