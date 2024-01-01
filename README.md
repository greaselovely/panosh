# panosh

Original scripts posted 2020.  There are better ways but I find these to be useful occasionally.

A small collection of shell scripts I use to manage Palo Alto Networks firewalls.

Only tested using Ubuntu 18, 20, 22, 24 and some limited MacOS under bash but isn't reliable, re-written for linux.

The initial scripts published use all native tools but because we are parsing the PAN XML from the API calls, we need you to install `xmllint`.

`sudo apt-get install --yes libxml2`

Email notifications are using sendmail, so you'll have to install sendmail and configure it.  I setup mine to forward mail, but your config will depend on your environment.

Also, you'll have to `chmod +x` the shell scripts to make them executable, otherwise call them with `bash scriptname`

### Very Important
Do not use underscores for your inventory hostnames.  That is the file separator by default, unless you change it.

---

### var.sh

A collection of variables being sourced from other scripts.  Update this file as needed for paths you prefer

### add-inventory.sh

Creates the inventory list of firewalls when it doesn't exist, which will be the case when you first run any script.  It will ask you for the friendly name that you want to call the firewall (I usually use the actual hostname of the firewall), the IP address (that is accessible for management), the management TCP port (by default is 443, but if you have GlobalProtect running, it is changed to 4443 in the case of managing the firewall from an external interface), username, password.   It attempts to reach the firewall, generate and retrieve the API key.  If it is successful, it will store most of that info (minus username and password) in the inventory txt file for use later.  Obviously this file becomes highly sensitive once this info is kept in it.  Please ensure your firewall(s) are locked down for management on known good IP's, not just wide open to the inet.  An idea that is floating in my head is to encrypt or minimally encode the txt file or even just encode the API key, but for now this is what we have.

This file does not use var.sh so you'll have to modify this script as well for any path changes you want.

### reboot.sh

A reboot script, pretty dangerous.
This does not use the default inventory list, it references the rebootlist.txt.
I have the following in crontab:

`00 03 * * * /your/repo/path/panosh/reboot.sh`

This will check to see if there are any firewalls in the rebootlist.txt (found in the $bounce path) and if so, then at the scheduled time (in my case, 0300 / 3:00AM) it will reboot firewalls.

It sleeps for :30 min and then checks to see if the firewall is operational or not, and then will email you.  You may have to setup sendmail on your box to get email notifications.
  
### software-upgrade.sh

My favorite and the one that caused me the most heartburn.  But it works pretty well, simplifies downloads and software installs.  Limited in some logic functionality but it will do the job.  It would be nice to make a decision on if a base image has been downloaded and/or is needed, but haven't got there.  So you just have to know that you need to do that.  I don't currently trust this to do multiple firewalls in a row unattended or otherwise, so I just do one at a time for now but I bet it could be massaged better.
  
  
### backup-configs.sh

Exports the device state and saves it as $hostname.tgz (which is based off the friendly name you give it in the inventory file).  This file can be used to restore the entire config to a new device should you ever have to do that.  If you ever hope to have to restore a new firewall, this is a much easier way to do it.  Schedule this to run via crontab as well to automate backups.

### schedule-reboot.sh

Just finds whatever device you're looking for in the inventory and moves it over to the rebootlist.  I needed a way to schedule reboots easily instead of manually editing the file.  That's all this does, lazy man's script.

### serial-number.sh

A much lesser used script, was used early on for random needs, but this just gets the SN, hostname and model of firewall.  Useful, but only a little.
  
### dyn_updates.sh

A much lesser used script, was used early on to audit dynamic updates as firewalls weren't being configured consistently.  Relies on the backup_configs.sh script to have run or it will call it if here are no configurations backed up already for today. It will extract the running-config.xml, and then query the dynamic updates.  It will iterate the XML and provide output on what the firewall is licensed for.
  
### panos-version.sh

I use this one more often than not, it can give me a quick glance at a list of firewalls and the versions they are running.  And then I can run the software ugprade as needed and then schedule reboots.  And the world harmoniously begins to hum.

### address-update.sh

Originally used to check that "OutsideIP" as an address object was the same as the outside / untrust interface for the purpose of allowing traffic inbound for specific use cases.