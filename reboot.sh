#!/bin/bash

# A reboot script, pretty dangerous.
# This does not use the default inventory
# list, it references the rebootlist.txt.
# I have the following in crontab:

# `00 03 * * * /your/repo/path/panosh/reboot.sh`

# This will check to see if there are any 
# firewalls in the rebootlist.txt (found 
# in the $bounce path) and if so, then at 
# the scheduled time (in my case, 0300 / 
# 3:00AM) it will reboot firewalls.

# It sleeps for :30 min and then checks to
# see if the firewall is operational or 
# not, and then will email you.  You may
# have to setup sendmail on your box to 
# get email notifications.

################################
########## SETTINGS ############

subfolder="reboots"
source "./var.sh"
rb="$bounce/$rebootlist"

equipment=$(cat $rb | sort -r 2>/dev/null)



################################
####### SETTINGS END############



function reboot_frwl(){
	# REBOOT COMMAND!
	# VERY DANGEROUS!
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	apiaction="api/?&type=op&cmd="
	apixpath=""
	apielement="<request><restart><system></system></restart></request>"
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	# JUST FOR TESTING:
	#apielement="<target><show></show></target>"
	time1=$(date +%H:%M:%S)
	curl --max-time 59.11 -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"
	echo -e "${info}$inv_name		Start: $time1" >> "$bounce/reboots.log"
}

function validate_frwl(){
	# show system info to validate firewall upon reboot
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	time2=$(date +%H:%M:%S)
	apiaction="api/?&type=op&cmd="
	apixpath=""
	apielement="<show><system><info></info></system></show>"
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	curl -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"
	statuscheck=$(xmllint --xpath "string(//hostname/text())" "$file_name" 2>/dev/null)
	
	if [ -z "$statuscheck" ]
		then
			version="Offline"
		else
			uptime=$(xmllint --xpath "string(//uptime/text())" "$file_name")
			version=$(xmllint --xpath "string(//sw-version/text())" "$file_name")
	fi
	
}

if [ ! -e "$bounce/reboots.tmp" ]; 
	then 
		touch "$bounce/reboots.tmp"
fi

if [ ! -e "$bounce/reboots.log" ]; 
	then 
		touch "$bounce/reboots.log"
fi

if [ -z "$equipment" ]; 
	then 
		echo -e "${info}No reboots on $today!" >> "$bounce/reboots.log"
		echo -e "${info}No reboots on $today!"
		exit 0
fi


echo -e "${info}$today" > "$bounce/reboots.tmp"
echo -e "${info}$today" >> "$bounce/reboots.log"
echo -e "${info}" >> "$bounce/reboots.tmp"
echo -e "${info}Name Version" >> "$bounce/reboots.tmp"

#########################################
########## Issue All Reboots ############

for i in $(echo -e "$equipment");
	do 
		inv_name=$(echo $i | awk 'BEGIN{FS="_";}{print $1}')
		ip=$(echo $i | awk 'BEGIN{FS="_";}{print $2}')
		port=$(echo $i | awk 'BEGIN{FS="_";}{print $3}')
		key=$(echo $i | awk 'BEGIN{FS="_";}{print $4}')

reboot_frwl

done

#nap time
sleep 1800

#########################################
########## Check On Reboots #############

clear

equipment=$(cat $rb | sort -r 2>/dev/null)

if [ -z "$equipment" ]; 
	then 
		echo -e "${info}Nothing In Inventory To Check" >> "$bounce/reboots.log"
		echo -e "${info}Nothing In Inventory To Check"
		exit 0
fi

for i in $(echo -e "$equipment");
	do 
		name=$(echo $i | awk 'BEGIN{FS="_";}{print $1}')
		ip=$(echo $i | awk 'BEGIN{FS="_";}{print $2}')
		port=$(echo $i | awk 'BEGIN{FS="_";}{print $3}')
		key=$(echo $i | awk 'BEGIN{FS="_";}{print $4}')

validate_frwl

time3=$(date +%H:%M:%S)


echo -e "${info}$inv_name $version" >> "$bounce/reboots.tmp"
echo -e "${info}$inv_name		End: $time3		$version" >> "$bounce/reboots.log"

done
########## Check On Reboots #############
#########################################




# #########################################
# ######## Email Notifications ############

# echo 'Content-Type: text/html; charset="us-ascii" ' > "$bounce/reboots.html"
# echo -e "${info}<html>" >> "$bounce/reboots.html"
# echo -e "${info}<body>" >> "$bounce/reboots.html"
# awk 'BEGIN{print "<table>"} {print "<tr>";for(i=1;i<=NF;i++)print "<td>" $i"</td>";print "</tr>"} END{print "</table>"}' "$bounce/reboots.tmp"  >> "$bounce/reboots.html"
# echo -e "${info}</body>" >> "$bounce/reboots.html"
# echo -e "${info}</html>" >> "$bounce/reboots.html"

# (
# echo -e "${info}$emailfrom"
# echo -e "${info}$emailto"
# echo -e "${info}MIME-Version: 1.0"
# echo -e "${info}Subject: Firewall Reboots For $today" 
# echo -e "${info}Content-Type: text/html" 
# cat "$bounce/reboots.html"
# ) | /usr/sbin/sendmail -t

# ######## Email Notifications ############
# #########################################


> "$rb"
rm -rf "$dump"
