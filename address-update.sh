#!/bin/bash

# Originally used to check that "OutsideIP" as an address 
# object was the same as the outside / untrust interface
# for the purpose of allowing traffic inbound for specific
# use cases.

subfolder="address_object"
source "./var.sh"
interface_name="ethernet1/1"
object_name="OutsideIP"

function show_int() {
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	apiaction="api/?&type=op&cmd="
	apixpath=""
	apielement="<show><interface>$interface_name</interface></show>"
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	curl -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"	
	dhcp_intip=$(xmllint --xpath "string(//dyn-addr/member/text())" "$file_name" | sed 's/\/[0-9]\{1,2\}//g')
	static_intip=$(xmllint --xpath "string(//addr/member/text())" "$file_name" | sed 's/\/[0-9]\{1,2\}//g')
	if [ -n "$dhcp_intip" ]; then
	    intip=$dhcp_intip
	elif [ -n "$static_intip" ]; then
		intip=$static_intip
	else
		echo -e "${alert}No IP address found on ${interface_name} on ${inv_name}"
	fi

}

function show_obj() {
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	apiaction="api/?&type=config&action=show"
	apixpath="&xpath=/config/devices/entry%5B%40name='localhost.localdomain'%5D/vsys/entry%5B%40name='vsys1'%5D/address/entry%5B%40name='$object_name'%5D"
	apielement=""
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	curl -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"
	objip=$(xmllint --xpath "string(//ip-netmask/text())" "$file_name" | sed 's/\/32//g')
} 


function set_obj() {
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	apiaction="api/?&type=config&action=set"
	apixpath="&xpath=/config/devices/entry%5B%40name='localhost.localdomain'%5D/vsys/entry%5B%40name='vsys1'%5D/address/entry%5B%40name='OutsideIP'%5D"
	apielement="&element=<ip-netmask>$1</ip-netmask>"
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	curl -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"
} 


function commit() {
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	desc="Address_Object_Update"
	apiaction="/api/?type=commit&cmd=<commit><description>$desc</description></commit>"
	apixpath=""
	apielement=""
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	curl -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"
}

function error_check(){
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	# look for the latest from the xml output
	checkerror=$(grep -i "error" "$dump/$inv_name.sn" 2>/dev/null)
	errormessage=$(xmllint --xpath "string(//*[@status])" "$file_name" 2>/dev/null)
	if [ "$checkerror" ] || [ "$checkfailed" ]
		then 
			errormessage=$(xmllint --xpath "string(//*[@status])" "$file_name")
			failmessage=$(xmllint --xpath "string(//details/line/text())" "$file_name")
			echo -e "${info}$failmessage$errormessage" 
			echo
			exit 0
	fi
}


function clear_all_sessions() {
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	apiaction="/api/?type=op&cmd=<clear><session><all></all></session></clear>"
	apixpath=""
	apielement=""
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	curl -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"
	# maybe we'll put this in later but we'll need to see if the job has completed or not, additional logic I don't care about right now.
} 




if [ $1 ]
	then equipment=$(grep -i "$1" "$inventory")
	else equipment=$(cat "$inventory")
fi


for i in $(echo -e "$equipment");
	do 
		
		inv_name=$(echo $i | awk 'BEGIN{FS="_";}{print $1}')
		ip=$(echo $i | awk 'BEGIN{FS="_";}{print $2}')
		port=$(echo $i | awk 'BEGIN{FS="_";}{print $3}')
		key=$(echo $i | awk 'BEGIN{FS="_";}{print $4}')

		echo -e "\n\n${info}Attempting to access $inv_name..."

show_int
show_obj

if [ -z "${objip}" ]
	then
		echo -e "\n\n${info}${object_name} is not found on ${inv_name}" >> $dump/../ip.log
		echo -e "\n\n${info}${object_name} is not found on ${inv_name}"
fi

if [ -z "${intip}" ]
	then
		:
	else
		if [[ "${intip}" != "${objip}" ]]	
			then
				set_obj $intip
				error_check
				commit
				error_check
				echo -e "${info}${today} ${inv_name} was updated; --> Interface is: $intip --> Address Object was: $objip"  >> $dump/../ip.log
				echo -e "${info}${inv_name} was updated..."
			else
				echo -e "${info}${today} ${inv_name} - Interface ($intip) and Address Object ($objip) appear to be the same" >> $dump/../ip.log
				echo -e "\n${info}No changes right now!  Noice!\n"
		fi

fi
done


exit
# cleanup
rm -rf $dump