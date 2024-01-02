#!/bin/bash

# A much lesser used script, was used early on to audit dynamic 
# updates as firewalls weren't being configured consistently.  
# Relies on the backup_configs.sh script to have run or it will call 
# it if there are no configurations backed up already for today.
# It will extract the running-config.xml, and then query the dynamic updates.  
# It will iterate the XML and provide output on what the firewall
# is licensed for.

################################
########## SETTINGS ############

subfolder="configs"
source "./var.sh"
config_path="${HOME}/$vendor/configs/$today"

equipment=${1:-$(cat $inventory)}

################################
####### SETTINGS END############

# clear the log file
> "$dyndump/$win"

ensure_directory_exists "$dyndump"

function fetch_config() {
    source "./backup-configs.sh" $1
}

# Extract data from XML and format it
function extract_and_format_data() {
    echo "DEBUG: dir : $1"
    read -p "key..."
    ensure_directory_exists "$1"
    tar -xf "$1.tgz" -C "$1"
    local file="$1/running-config.xml"
    local hostname=$(xmllint --xpath "string(//hostname/text())" "$file")
    printf "%s\n" "$hostname" >> "$dyndump/$win"

    # Extract direct child element names under <update-schedule>
    local schedule_types=($(xmllint --shell "$file" <<< "cat //update-schedule/*" | awk -F'[<>]' '/^<[^\/][^>]*>$/ {print $2}' | sort -u))

    for type in "${schedule_types[@]}"; do
        local capitalized_type=$(echo -e "$type" | awk '{print toupper($0)}')
        local action=$(xmllint --xpath "string(//update-schedule/$type//action)" "$file")
        local sync=$(xmllint --xpath "string(//update-schedule/$type//recurring//sync-to-peer)" "$file")
        local time=$(xmllint --xpath "string(//update-schedule/$type//recurring/*/at)" "$file")
        local frequency=$(xmllint --xpath "name(//update-schedule/$type/recurring/*[at])" "$file")

        if [ -n "$action" ]
            then
                if [ -z "$sync" ]
                    then
                        printf "\t%s: %s %s at %s\n" "$capitalized_type" "$action" "$frequency" "$time" >> "$dyndump/$win"
                    else
                        printf "\t%s: %s %s at %s sync-to-peer: %s\n" "$capitalized_type" "$action" "$frequency" "$time" "$sync" >> "$dyndump/$win"
                fi

                if [ "$action" != "download-and-install" ]
                    then
                        printf "\tFix %s %s - it is set to %s\n" "$hostname" "$capitalized_type" "$action" | tr '[:lower:]' '[:upper:]' >> "$dyndump/$win"
                fi
        fi
    done

    printf "\n" >> "$dyndump/$win"
}

for i in $(echo -e "$equipment");
	do 
        inv_name=$(echo $i | awk -F'_' '{print $1}'  | awk '{print toupper($0)}')
        fetch_config "$inv_name"  
        extract_and_format_data "$config_path/$inv_name"
        rm -rf "$config_path/$inv_name"
done

# Display results

cat "$dyndump/$win"

