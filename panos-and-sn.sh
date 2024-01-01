#!/bin/bash

# Usage: ./script-name.sh
#     or ./script-name.sh HQ

# Utility script to get the SN, hostname, model and PAN-OS version of firewall(s). 

################################
########## SETTINGS ############

subfolder="sn"
source "./var.sh"


function sys_info() {
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	apiaction="api/?&type=op&cmd="
	apixpath=""
	apielement="<show><system><info></info></system></show>"
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	curl -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"	
	serial_number=$(xmllint --xpath "string(//serial/text())" "$file_name")
	hostname=$(xmllint --xpath "string(//devicename/text())" "$file_name")
	model_number=$(xmllint --xpath "string(//model/text())" "$file_name")
	sw_version=$(xmllint --xpath "string(//sw-version/text())" "$file_name")
}

function error_check(){
	checkerror=$(grep -i "error" "$file_name" 2>/dev/null)
	errormessage=$(xmllint --xpath "string(//*[@status])" "$file_name" 2>/dev/null)
	if [ "$checkerror" ] || [ "$checkfailed" ]
		then 
			errormessage=$(xmllint --xpath "string(//*[@status])" "$file_name")
			failmessage=$(xmllint --xpath "string(//details/line)" "$file_name")
			echo -e "${alert}$failmessage$errormessage\n" 
			exit 0
	fi
}



if [ $1 ]
	then equipment=$(grep -i $1 $inventory)
	else equipment=$(cat $inventory)
fi

> "$dump/$win"
clear
echo -e "Hostname\t\tModel\t\tSerial\t\tPAN-OS"  >> "$dump/$win"

for i in $(echo -e "$equipment");
	do 
		inv_name=$(echo $i | awk 'BEGIN{FS="_";}{print $1}')
		ip=$(echo $i | awk 'BEGIN{FS="_";}{print $2}')
		port=$(echo $i | awk 'BEGIN{FS="_";}{print $3}')
		key=$(echo $i | awk 'BEGIN{FS="_";}{print $4}')

	echo -en "${info}Attempting to access $inv_name...\033[0K\r"

	sys_info
	error_check

	echo -e "\t$inv_name\t\t$model_number\t\t$serial_number\t\t$sw_version">> "$dump/$win"
done;

clear
pan_sn=$(cat "$dump/$win" | column -t)
echo -e "$pan_sn\n\n"
