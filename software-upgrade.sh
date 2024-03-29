#!/bin/bash

# My favorite and the one that caused me the most heartburn.  
# But it works pretty well, simplifies downloads and software 
# installs.  Limited in some logic functionality but it will 
# do the job.  It would be nice to make a decision on if a base 
# image has been downloaded and/or is needed, but haven't got 
# there.  So you just have to know that you need to do that.  
# I don't currently trust this to do multiple firewalls in a 
# row unattended or otherwise, so I just do one at a time for 
# now but I bet it could be massaged better.

# Ideas:
# check for versions above the current running version and provide a menu option - completed 12.28.23
# check for versions above the current running version and also show base version that may be needed

################################
####### SETTINGS START##########
################################

# This can be run three ways:
# ./scriptname dev_name force (this avoids the latest version check and allows you to download a specific version)
#		I saw an issue where a hotfix version was marked by PAN as "latest" so I had to create this work around.
# ./scriptname WLP (or full hostname for grep to work)
# ./scriptname (you'll be prompted for info)


subfolder="software_upgrade"
source "./var.sh"


function TitleCaseConverter() {
    message=$(awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1' <<< $1)
	echo -e "${info}$message"
}

function show_system_info(){
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	apiaction="api/?&type=op&cmd="
	apixpath=""
	apielement="<show><system><info></info></system></show>"
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	curl -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"	
	actual_name=$(xmllint --xpath "string(//hostname/text())" "$file_name")
	sw_version=$(xmllint --xpath "string(//sw-version/text())" "$file_name")
	app_version=$(xmllint --xpath "string(//app-version/text())" "$file_name" | cut -c 1-4)
}

function request_system_software_info(){
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	apiaction="api/?&type=op&cmd="
	apixpath=""
	apielement="<request><system><software><info></info></software></system></request>"
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	curl -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"	
	# is_current is either yes or no
	is_current=$(xmllint --xpath "string(//versions/entry[current='yes']//version)" "$file_name")
	xmllint --xpath "//versions/entry[latest='yes']" "$file_name" > "$dump/$inv_name.info.xml"
	downloaded=$(xmllint --xpath "string(//downloaded)" "$dump/$inv_name.info.xml" 2>/dev/null)
}

function request_system_software_check(){
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	apiaction="api/?&type=op&cmd="
	apixpath=""
	apielement="<request><system><software><check></check></software></system></request>"
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	echo -e "${info}Checking with PAN..."
	curl -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"
	message=$(xmllint --xpath "string(//msg/text())" "$file_name")
	if [ -z "$message" ]
		then
			:
	else
		echo -e "${alert}${message}\n"
		END_MARKER_VAR=1
		cleanup_and_exit yes
	fi
	xmllint --xpath "//versions/entry[latest='yes']" "$file_name" > "$dump/$inv_name.latest.xml"
	current_panos_version=$(xmllint --xpath "string(//current/text())" "$dump/$inv_name.latest.xml" 2>/dev/null)
}

function error_check(){
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	checkerror=$(grep -i "error" "$file_name" 2>/dev/null)
	errormessage=$(xmllint --xpath "string(//*[@status])" "$file_name" 2>/dev/null)
	if [ "$checkerror" ] || [ "$checkfailed" ]
		then 
			errormessage=$(xmllint --xpath "string(//*[@status])" "$file_name")
			failmessage=$(xmllint --xpath "string(//details/line)" "$file_name")
			echo -e "${info}$failmessage$errormessage" 
			END_MARKER_VAR=1
			cleanup_and_exit yes
	fi
}

function show_job_id(){
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	apiaction="api/?&type=op&cmd="
	apixpath=""
	apielement="<show><jobs><id>$jobid</id></jobs></show>"
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	curl -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"
	show_job_id_message=$(xmllint --xpath "string(//details/line/text())" "$file_name" 2>/dev/null)
}	

function request_content_upgrade_download_latest(){
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	echo -e "${info}Latest Content Download First..."
	apiaction="api/?&type=op&cmd="
	apixpath=""
	apielement="<request><content><upgrade><download><latest></latest></download></upgrade></content></request>"
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	curl -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"
	jobid=$(xmllint --xpath "string(//job/text())" "$file_name")
}

function request_content_upgrade_install_latest(){
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	echo -e "${info}Latest Content Install Now..."
	apiaction="api/?&type=op&cmd="
	apixpath=""
	apielement="<request><content><upgrade><install><version>latest</version></install></upgrade></content></request>"
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	curl -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"
	jobid=$(xmllint --xpath "string(//job/text())" "$file_name")
}


function panos_version_choices() {
    running_version=$1
    xml_file=$2

    # Function to compare versions
    version_gt() { test "$(echo -e "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; }

    # Extract versions using xmllint
    versions=($(xmllint --xpath '//entry/version/text()' "$xml_file"))

    # Array to hold versions greater than running_version
    greater_versions=()

    # Populate greater_versions array
    for available_version in "${versions[@]}"; do
        if version_gt $available_version $running_version; then
            greater_versions+=("$available_version")
        fi
    done

    # Check if there are any greater versions
    if [ ${#greater_versions[@]} -eq 0 ]; then
        echo -e "${info}No versions available higher than $running_version."
		END_MARKER_VAR=1
		cleanup_and_exit yes
    fi

    # Display the greater versions as a menu
    echo -e "${info}Available Versions:\n"
    for i in "${!greater_versions[@]}"; do
        echo -e "$((i+1)).\t${greater_versions[i]}"
    done

    # Prompt user to select a version
    while true; do
        read -p "    Select a version by number (1-${#greater_versions[@]}): " selection
        if [[ $selection =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#greater_versions[@]}" ]; then
            selected_version=${greater_versions[$((selection-1))]}
            break
        else
            echo -e "${info}Invalid selection. Please try again.\n"
        fi
    done

    downloaded=$(xmllint --xpath "//entry[version/text()='$selected_version']/downloaded/text()" "$xml_file")
}


function panos_download(){
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	apiaction="api/?&type=op&cmd="
	apixpath=""
	apielement="<request><system><software><download><version>$selected_version</version><sync-to-peer>yes</sync-to-peer></download></software></system></request>"
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	echo -e "${info}Downloading..."
	curl -sk --connect-timeout 59.01 -# --output "$dump/$inv_name.download" "$apiurl"
	jobid=$(xmllint --xpath "string(//job)" "$dump/$inv_name.download")
}		

function panos_download_only(){
	echo -e "${info}Confirming Download Only..."
	request_system_software_info
	echo -e "${info}Downloaded : $downloaded"
	echo -e "${info}Skipping Install...            "
}

function panos_install(){
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	echo -e "${info}Installing...              "
	apiaction="api/?&type=op&cmd="
	apixpath=""
	apielement="<request><system><software><install><version>$selected_version</version></install></software></system></request>"
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	curl -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"
	jobid=$(xmllint --xpath "string(//job)" "$file_name")	
}

function panos_install_verified(){
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	echo -ne "\tVerifying Install Initiated...\033[0K\r"
	apiaction="api/?&type=op&cmd="
	apixpath=""
	apielement="<show><jobs><id>$jobid</id></jobs></show>"
	apikey="&key=$key"
	apiurl="https://$ip":"$port/$apiaction$apixpath$apielement$apikey"
	curl -sk --connect-timeout 59.01 -# --output "$file_name" "$apiurl"
	installstatus=$(xmllint --xpath "string(//job//status)" "$file_name")
	installresult=$(xmllint --xpath "string(//job//result)" "$file_name")
	sleep $sleep_seconds
}

function job_progress(){
	local file_name="$dump/$inv_name.$FUNCNAME.xml"
	progress="0"
		while [ "$progress" -lt 99 ];
			do
				show_job_id
				echo -ne "${info}Job ID $jobid is at $progress%\033[0K\r"
				sleep $sleep_seconds
				# PANW replaces the progress integer with the date and time it ended:
    				# IE:   2023/09/28 15:18:24
				# the while loop breaks when it hits this, so this regex will simply replace that with 99
				# so that the while loop will exit
				progress=$(xmllint --xpath "string(//progress/text())" "$dump/$inv_name.show_job_id.xml" | sed 's/[0-9]\{4\}\/[0-9]\{2\}\/[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}/99/g')
		done
	job_status=""
		while [ "$status" != "FIN" ];
			do
				show_job_id
				status=$(xmllint --xpath "string(//status/text())" "$dump/$inv_name.show_job_id.xml")
				echo -ne "\tJob ID $jobid is $status...\033[0K\r"
				sleep $sleep_seconds
		done
	result=$(xmllint --xpath "string(//result//result/text())" "$dump/$inv_name.show_job_id.xml")
		if [ $result == "FAIL" ]
			then
				line=$(xmllint --xpath "string(//line/text())" "$dump/$inv_name.show_job_id.xml")
				echo -e "${info}Job $jobid has $line..."
				cleanup_and_exit yes
		fi
}


function cleanup_and_exit(){
	local do_we_exit=$1
	all_vars=$(compgen -v)
	start_line=$(echo "$all_vars" | grep -n "^START_MARKER_VAR$" | cut -d: -f1)
	end_line=$(echo "$all_vars" | grep -n "^END_MARKER_VAR$" | cut -d: -f1)
	vars_to_unset=$(echo "$all_vars" | sed -n "${start_line},${end_line}p")
	for var in $vars_to_unset; do
		if [[ "$var" != "START_MARKER_VAR" && "$var" != "END_MARKER_VAR" ]]; then
			unset $var
		fi
	done
	if [ "$do_we_exit" == "yes" ]
	then
		exit
	fi
}


# main:

START_MARKER_VAR=1

clear

default_value="all"
frwl=$1

# Prompt the user if no argument is given
if [ -z "$frwl" ]; then
    echo -en "${info}Provide the partial or full firewall hostname "
    read -p "[$default_value]: " frwl
    frwl=${frwl:-$default_value}
fi

if [ "$frwl" == "all" ]; then
    equipment=$(cat "$inventory")
else
    equipment=$(grep -i "$frwl" "$inventory")
fi

if [ -z "$equipment" ]; then
    echo -e "${alert}${frwl} Not Detected in Inventory, Exiting...\n"
	END_MARKER_VAR=1
	cleanup_and_exit
fi

for i in $(echo -e "$equipment");
	do 
		inv_name=$(echo $i | awk 'BEGIN{FS="_";}{print $1}')
		ip=$(echo $i | awk 'BEGIN{FS="_";}{print $2}')
		port=$(echo $i | awk 'BEGIN{FS="_";}{print $3}')
		key=$(echo $i | awk 'BEGIN{FS="_";}{print $4}')

	rm "$dump/$inv_name."* 2>/dev/null
	rm "$dump/$inv_name" 2>/dev/null

	clear

	show_system_info

	echo -e "${info}${inv_name}"
	request_system_software_info
	clear
	echo -e "${info}$actual_name  ($sw_version)"
	request_system_software_check


	if [ "$app_version" -le "8786" ]
		then
			request_content_upgrade_download_latest
			job_progress
			request_content_upgrade_install_latest
			job_progress
	fi

	error_check

	if [ "$2" == "force" ]
		then
			echo -e "${alert}Forcing Install..."
		else
			if [ "$is_current" == "yes" ]
				then 
				echo -e "\n${info}This device is already running the latest PANOS version, nothing to do.  Exiting.\n\n"
				END_MARKER_VAR=1
				cleanup_and_exit yes
			fi
	fi 


	### determine which version to install
	### "returns" $selected_version
	panos_version_choices $sw_version "$dump/$inv_name.request_system_software_check.xml"


	if [ "$downloaded" == "yes" ]
		then 
			default_value="n"
			echo -en "\n${question}This version is already downloaded, do you want to download it again? "
			read -p "(y/n) [$default_value]: " downloadagain
			downloadagain=${downloadagain:-default_value}
	fi


	### prompting for downloads, installs ###
	prompt_valid=false
	while [ "$prompt_valid" = false ]; do
		if [ "$downloaded" = "yes" ]; then
			default_value="y"
			echo -en "${question}Do you want to install $selected_version on $actual_name? "
			read -p "(y/n) [$default_value]: " installonly
			installonly=${installonly:-$default_value}

			if [[ "$installonly" = "y" || "$installonly" = "n" ]]; then
				prompt_valid=true
			fi
		else
			default_value="i"
			echo -en "${question}Do you want to download only -or- install $selected_version on $actual_name? "
			read -p "(d/i) [$default_value]: " downloadorinstall
			downloadorinstall=${downloadorinstall:-$default_value}

			if [[ "$downloadorinstall" = "d" || "$downloadorinstall" = "i" ]]; then
				prompt_valid=true
			fi
		fi
	done

	# reboot question ###
	if [ "$downloadorinstall" = "i" ] || [ "$installonly" == "y" ]
		then
			default_value="y"
			echo -en "${question}Do you want to schedule a reboot of $actual_name? "
			read -p "(y/n) [$default_value]: " rebootquestion
			rebootquestion=${rebootquestion:-$default_value}
	fi
	### end prompting ###



	### start working ###
	if [ "$downloadagain" == "y" ]
		then
			panos_download
			error_check
			job_progress
			echo -e "${info}Verifying Download...                  "
			show_job_id
			TitleCaseConverter "$show_job_id_message"
			error_check
	fi


	if [ "$downloadorinstall" == 'i' ]  || [ "$installonly" == "y" ]
		then
			panos_download
			error_check
			echo -e "${info}Verifying Download...                  "
			show_job_id
			TitleCaseConverter "$show_job_id_message"
			error_check
			panos_install
			error_check
			show_job_id
			error_check
			panos_install_verified
			error_check
			job_progress

	fi

	if [ "$downloadorinstall" == "d" ] 
		then 
			panos_download
			echo -e "${info}Verifying Download...                  "
			show_job_id
			job_progress
			TitleCaseConverter "$show_job_id_message"
			error_check

	fi

	if [ "$installonly" == "n" ]
		then
			:
		else
			if [ "$rebootquestion" = "y" ];
				then 
					echo -e "${inv_name}_${ip}_${port}_${key}" >> "$bounce/$rebootlist"
					echo -e "${info}Current Reboots Scheduled :\n"
					scheduled=$(cat "$bounce/$rebootlist")
					for i in $(echo -e "$scheduled");
						do 
							echo -e "${info}$i" | awk 'BEGIN{FS="_";}{print $1}'
					done
				else
					echo -e "${info}We are not scheduling $actual_name for reboot, you'll have to reboot it manually."
			fi
	fi




	rm "$dump/$inv_name."* 2>/dev/null
	rm "$dump/$inv_name" 2>/dev/null

	# unset script variables
	END_MARKER_VAR=1

	cleanup_and_exit no

done