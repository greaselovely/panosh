#!/bin/bash

# Exports the device state and saves it as $hostname.tgz 
# (which is based off the friendly name you give it in the 
# inventory file).  This file can be used to restore the 
# entire config to a new device should you ever have to do 
# that.  If you ever hope to have to restore a new firewall, 
# this is a much easier way to do it.  Schedule this to run 
# via crontab as well to automate backups.



clear
################################
########## SETTINGS ############

subfolder="configs"
source "./var.sh"

# Usage: ./configs.sh
#     or ./configs.sh HQ

if [ "$1" ]
	echo "DEBUG : var passed is : $1"
	then 
		equipment=$(grep -i $1 $inventory | sort)
	else 
		equipment=$(cat $inventory | sort)
fi

################################
####### SETTINGS END############

function get_config() {
	mkdir -p "$dump/$inv_name"
	local file_name="$dump/$inv_name.tgz"
	apiaction="api/?type=export&category=device-state"
	apixpath=""
	apielement=""
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	curl -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"
}

function check_hostname(){
	tar -xf "$dump/$inv_name.tgz" -C "$dump/$inv_name"
	hostname=$(xmllint --xpath "string(//hostname/text())" "$dump/$inv_name/running-config.xml")
}

# starts the loop and defines the separator and prints out what we have defined in the inventory file.
for i in $(echo -e "$equipment");
	do 
		inv_name=$(echo $i | awk 'BEGIN{FS="_";}{print $1}')
		ip=$(echo $i | awk 'BEGIN{FS="_";}{print $2}')
		port=$(echo $i | awk 'BEGIN{FS="_";}{print $3}')
		key=$(echo $i | awk 'BEGIN{FS="_";}{print $4}')
		
# clear
echo -e "\n\n${info}Attempting to Backup $inv_name..."

get_config

check_hostname

# Check if the file was transferred
# by querying the xml file for the name
if [ -z "$hostname" ]
	then status="FAILED"
	else status="SUCCESS"
fi

rm -rf "$dump/$hostname"
echo -e "$today\t$inv_name\t$hostname\t$status" >> "$dump/$win"

done;

# Send email if you have sendmail configured.

# echo 'Content-Type: text/html; charset="us-ascii" ' > "$dump/email.html"
# echo -e "<html>" >> "$dump/email.html"
# echo -e "<body>" >> "$dump/email.html"
# awk 'BEGIN{print "<table>"} {print "<tr>";for(i=1;i<=NF;i++)print "<td>" $i"</td>";print "</tr>"} END{print "</table>"}' "$dump/$win"  >> "$dump/email.html"
# echo -e "</body>" >> "$dump/email.html"
# echo -e "</html>" >> "$dump/email.html"

# (
# echo -e "$emailfrom"
# echo -e "$emailto"
# echo -e "MIME-Version: 1.0"
# echo -e "Subject: Firewall Backups For $today" 
# echo -e "Content-Type: text/html" 
# cat "$dump/email.html"
# ) | /usr/sbin/sendmail -t

