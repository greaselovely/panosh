#!/bin/bash


# Just finds whatever device you're looking for in the inventory 
# and moves it over to the rebootlist.  I needed a way to schedule
# reboots easily instead of manually editing the file.  That's all
# this does, lazy man's script.



################################
########## SETTINGS ############


subfolder="reboots"
source "./var.sh"

########## SETTINGS ############
################################


clear

if [ $1 ]
	then
		device=$(grep -i "$1" "$inventory")
	else
		default_value="frwl"
		echo
		read -p "    Name or part of name of the device you want to schedule [$default_value]: " tempdevice
		tempdevice=${tempdevice:-$default_value}
		device=$(grep -i "$tempdevice" "$inventory")
fi
	

if [ -z "$device" ]
	then
		echo
		echo -e "${info}  Cannot find $1$tempdevice in inventory, exiting..."
		echo
		exit 0
fi

schedulecheck=$(grep -i "$device" "$bounce/$rebootlist")

if [ "$device" == "$schedulecheck" ]
	then
		echo
		echo -e "${info}That device appears to be scheduled already.  Exiting..."
		echo
		exit 0
fi

for i in $(echo -e "$device");
	do inv_name=$(echo $i | awk 'BEGIN{FS="_";}{print $1}'| tr "[:lower:]" "[:upper:]")
done
default_value="y"
echo
echo -e "${info}Please confirm you want to schedule $inv_name for reboot? "
read -p "(y/n) [$default_value]" confirmreboot
confirmreboot=${confirmreboot:-$default_value}

if [ "$confirmreboot" = "y" ];
	then 
		echo
		echo -e "${info}This has been sent over for reboot overnight!"
		echo -e "${info}$device" >> "$bounce/$rebootlist"
	else 
		echo
		echo -e "${info}Word.  We did NOT schedule $inv_name for reboot."
fi

echo
echo -e "${info}Here is what is scheduled : "
echo

scheduled=$(cat "$bounce/$rebootlist")

for i in $(echo -e "$scheduled");
	do 
		echo -e "${info}$i" | awk 'BEGIN{FS="_";}{print $1}'
done
echo
