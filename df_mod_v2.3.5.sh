#!/bin/bash
# name          : df_mod.sh
# desciption    : show differing FS usage, debian 8|9|10|11  SFOS 3.X
# autor         : speefak (itoss@gmx.de)
# licence       : (CC) BY-NC-SA
  VERSION=2.3.5
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
 ConfigFile=$HOME/.dff.cfg
 RequiredPackets="bash sed ncat"
 LANDevice=$(ip route | grep default | awk -F "dev " '{print $2}' | cut -d " " -f1 | head -n1)
 LANHostGrepEx=$(ip -br addr show $LANDevice | awk '{print $3}' | awk -F "." '{printf "%s.%s.%s." , $1,$2,$3 }')
 OutputWidth=$(tput cols)
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
###########################################   define functions   ###########################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
usage () {
cat << USAGE
 Disk free frontend - display free disk space - version $VERSION
 Usage: $(basename $0) <option>

 -h, --help      	display help
 -v, --verbose   	display all filesystems
 -m, --monochrome	disable color
 -l, --listconfig	show configuration
 -c, --configure 	create new configuration
 -r, --reconfigure 	reconfigure configuration
 -cfrp		 	check for required packets
USAGE
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
check_for_required_packages () {
	InstalledPacketList=$(dpkg -l | grep ii | awk '{print $2}' | cut -d ":" -f1)
	for Packet in $RequiredPackets ; do
		if [[ -z $(grep -w "$Packet" <<< $InstalledPacketList) ]]; then
			MissingPackets=$(echo $MissingPackets $Packet)
		fi
	done
	
	# print status message / install dialog
	if [[ -n $MissingPackets ]]; then
		printf "missing packets: \e[0;31m $MissingPackets\e[0m\n"$(tput sgr0)
		read -e -p "install required packets ? (Y/N) " -i "Y" InstallMissingPackets
		if [[ $InstallMissingPackets == [Yy] ]]; then
			# install software packets
			sudo apt update
			sudo apt install -y $MissingPackets || exit 1
		else
			printf "programm error: missing packets : $MissingPackets\n"$(tput sgr0)
			exit 1
		fi
	else
		printf "\e[0;32m all required packets detected\e[0m\n"
	fi
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
configure_dialog () {
	# create config file
	ConfigParameterList=$(cat $0 | grep -A71 "configure_dialog () {" | grep "read -e -p \" Enter" | awk -F " " '{print $NF}')
	DetectedOS=$(cat /etc/*release* | tac | grep PRETTY_NAME | head -n1 | cut -d "=" -f2 | tr -d '"')

	if [[ -n $(grep Sailfish <<< $DetectedOS) ]]; then
		if [[ -n $(cat $ConfigFile 2>/dev/null | grep "Reconfigure=true") ]]; then
			sed -i '/Reconfigure=true/d' $ConfigFile
			sed -i '/CreateNewConfig=true/d' $ConfigFile
			nano $ConfigFile
		else
			# load default configuration
			rm -f $ConfigFile
			OperatingSystem=$DetectedOS
			FSLocalSystems="/"
			FSLocalStorage="$(df -hTP| grep -w "/home$"|cut -d " " -f1) $(mount -l | grep " /run/media/nemo" | cut -d " " -f3)"
			FSRemote="ssh fuse smb"
			FSExclude="snap"
			SortFSColumnSystem="7"
			SortFSColumnStorage="7"
			SortFSColumnRemote="7"
			FrameColor="1"
			ColumnHeaderColor="2"
			ColumnSumaryColor="3"
			GraphThresholdLow="59"					# 59% - 5% GraphRoundThreshold => 54%
			GraphThresholdMid="95"					# 95% - 5% GraphRoundThreshold => 90%
			GraphThresholdHigh="100"
			GraphRoundThreshold="5"
			GraphColorLow="2"
			GraphColorMid="3"
			GraphColorHigh="1"
			ColumnSumaryCalc="disabled"
			MaxDeviceLength=dyn
			MaxMountpointLength=dyn
		fi
	else
		# display var input prompt and default value, enter/edit value
		df -hT | grep -v tmpfs
		printf "\n"

		read -e -p " Enter local filesystems (main system e.g. /dev/sda1 ...): " -i "${FSLocalSystems:-$(df | grep -w "/" |cut -d " " -f1)}" FSLocalSystems
		read -e -p " Enter local storage filesystems (storage e.g. sda5 sdb1 /home ...): " -i "${FSLocalStorage:-$(df | grep -w "/home$"|cut -d " " -f1)}" FSLocalStorage
		read -e -p " Enter remote FS (e.g. fuse ssh smb ...): " -i "${FSRemote:-ssh fuse smb}" FSRemote
		read -e -p " Enter excluded FS (e.g. snap ...): " -i "${FSExclude:-snap}" FSExclude
		read -e -p " Enter sorting column number for FS => local systems: " -i "${SortFSColumnSystem:-7}" SortFSColumnSystem
		read -e -p " Enter sorting column number for FS => local storage: " -i "${SortFSColumnStorage:-7}" SortFSColumnStorage
		read -e -p " Enter sorting column number for FS => remote storage: " -i "${SortFSColumnRemote:-7}" SortFSColumnRemote
		read -e -p " Enter frame color ( default red ): " -i "${FrameColor:-1}" FrameColor
		read -e -p " Enter column header color (default green): " -i "${ColumnHeaderColor:-2}" ColumnHeaderColor
		read -e -p " Enter column summary color (default green): " -i "${ColumnSumaryColor:-3}" ColumnSumaryColor
		read -e -p " Enter graph range low % (default 0-59): 0-" -i "${GraphThresholdLow:-59}" GraphThresholdLow
		read -e -p " Enter graph range mid % (default 60-89): $(($GraphThresholdLow +1 ))-" -i "${GraphThresholdMid:-89}" GraphThresholdMid
		read -e -p " Enter graph range high % (default 90-100): $(($GraphThresholdMid +1 ))-" -i "${GraphThresholdHigh:-100}" GraphThresholdHigh
		read -e -p " Enter max length device column (digit|dynamic): " -i "${MaxDeviceLength:-dyn}" MaxDeviceLength
		read -e -p " Enter Max length mountpoint column (digit|dynamic): " -i "${MaxMountpointLength:-dyn}" MaxMountpointLength
		GraphRangeLow=$(echo 0-$GraphThresholdLow)
		GraphRangeMid="$(( $GraphThresholdLow +1 ))-$GraphThresholdMid"
		GraphRangeHigh="$(( $GraphThresholdMid +1 ))-100"
		read -e -p " Enter graph round threshold (default 5): " -i "${GraphRoundThreshold:-5}" GraphRoundThreshold
		read -e -p " Enter graph color low $GraphRangeLow% (default green): " -i "${GraphColorLow:-2}" GraphColorLow
		read -e -p " Enter graph color mid $GraphRangeMid% (default yellow): " -i "${GraphColorMid:-3}" GraphColorMid
		read -e -p " Enter graph color high $GraphRangeHigh% (default red): " -i "${GraphColorHigh:-1}" GraphColorHigh
		read -e -p " Enter default column sumary output (enable|disable): " -i "${ColumnSumaryCalc:-disabled}" ColumnSumaryCalc	
		read -e -p " Enter operating system: " -i "${OperatingSystem:-$DetectedOS}" OperatingSystem

		# set dummy var for empty value to avoid grep error
		if [[ -z $FSLocalStorage ]]; then FSLocalStorage=none; fi

		# print new Vars
		printf "\n new configuration values: \n\n"
		for i in $ConfigParameterList MaxDeviceLength MaxMountpointLength; do
			echo " $i=\""$(eval echo $(echo "$"$i))\"
		done

		# check for existing config file
		if [[ -s $ConfigFile ]]; then
			printf "\n"
			read -e -p " overwrite existing configuration (y/n) " -i "y" OverwriteConfig
			if [[ $OverwriteConfig == [yY] ]]; then
				rm $ConfigFile
			else
				sed -i '/Reconfigure=true/d' $ConfigFile
				sed -i '/CreateNewConfig=true/d' $ConfigFile
				printf "\n existing configuration :\n\n"
				cat $ConfigFile
				exit
			fi
		fi
	fi

	# write Vars to config file
	echo "#created $(date +%F)" > "$ConfigFile"
	for i in $ConfigParameterList MaxDeviceLength MaxMountpointLength; do
		echo "$i=\""$(eval echo $(echo "$"$i))\" >> "$ConfigFile"
	done

	printf "\n configuration saved in: $ConfigFile\n"
	$0
	exit
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
load_processing_vars () {

    # define colors
    if [[ -z $MonochromeOutput ]]; then 
	FrameColor=$(tput setaf $FrameColor)
	ColumnHeaderColor=$(tput setaf $ColumnHeaderColor)
	ColumnSumaryColor=$(tput setaf $ColumnSumaryColor)
	GraphColorLow=$(tput setaf $GraphColorLow)
	GraphColorMid=$(tput setaf $GraphColorMid)
	GraphColorHigh=$(tput setaf $GraphColorHigh)
	ResetColor=$(tput sgr0) 
    else
	FrameColor=$(tput setaf 7)
	ColumnHeaderColor=$(tput setaf 7)
	ColumnSumaryColor=$(tput setaf 7)
	GraphColorLow=$(tput setaf 7)
	GraphColorMid=$(tput setaf 7)
	GraphColorHigh=$(tput setaf 7)
    fi

    ColumnHeader="System-Device FS-Type Size Used Avail Used% Mountpoint Used-Graph"
    SeperatorLine="${FrameColor}$(printf '%*s' "$OutputWidth" | tr ' ' '-')${ResetColor}"

    FSExclude=$( sed 's/ /\\|/g' <<< "$FSExclude")

    FSLocalSystemList=$(df -hTP | sed '1,1d'| grep -vw "$FSExclude" 2>/dev/null | \
            egrep -w $(echo $FSLocalSystems| tr " " "|") | \
            awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnSystem )

    FSLocalStorageList=$(df -hTP | sed '1,1d' | grep -v localhost | grep -vw "$FSExclude" 2>/dev/null | \
            egrep $(echo $FSLocalStorage| tr " " "|") | \
            awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnStorage )

    FSRemoveableList=$(df -hTP | sed '1,1d' | grep -v tmpfs | grep -vw "$FSExclude" 2>/dev/null | \
            egrep -v $(echo $FSLocalSystems $FSLocalStorage $FSRemote| tr " " "|") | tr ":" " " | \
            awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnStorage)

    # Korrigierte Zeile für Remote (SSHFS) – ALLE 9 Felder behalten!
    FSRemoteList=$(df -hTP | sed '1,1d' | grep -vw "$FSExclude" 2>/dev/null | \
            egrep -w $(echo $FSRemote| tr " " "|") | \
            awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnRemote )

    # configure max string lenght, var=digit use digit, else calculate digit
    if [[ ! "$MaxDeviceLength" =~ ^[0-9]+$ ]]; then MaxDeviceLength=$(df -x tmpfs | awk '{print length($1)}' | sort -nr | head -1); fi
    if [[ ! "$MaxMountpointLength" =~ ^[0-9]+$ ]]; then MaxMountpointLength=$(df -x tmpfs | awk '{print length($NF)}' | sort -nr | head -1); fi
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
check_for_LAN_host () {
	# write vars: FSRemoteListLAN / FSRemoteListLAN from FSRemoteList
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	for HostLocation in $FSRemoteList ; do
		# get host IP
		HostAdress=$(echo "$HostLocation" | awk -F "@" '{printf "%s \n", $2}' | cut -d " " -f1)
		if [[ -n $(grep ^[[:digit:]] <<< $HostAdress) ]]; then
			HostIP="$HostAdress"
		elif [[ -n $(grep ^[[:alpha:]] <<< $HostAdress) ]]; then
			HostIP=$(nslookup $HostAdress | grep "Address: " | awk '{print $2}')
		fi
		if [[ -n $( egrep "$LANHostGrepEx|127.0.0.1" <<< $HostIP)  ]]; then
			# "$HostIP is LAN"		
			FSRemoteListLAN=$(echo -en "$FSRemoteListLAN""\n""$HostLocation" )
		else 
			# "$HostIP is WAN"
			FSRemoteListWAN=$(echo -en "$FSRemoteListWAN""\n""$HostLocation" )
		fi
	done
	IFS=$SAVEIFS
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
calculate_SI_prefix () {
	CalcResult=$( if [[ $(wc -m <<< $1) -gt 13 ]]; then
		printf $(bc -l <<< $1/2162516033536)P
	elif [[ $(wc -m <<< $1) -gt 10 ]]; then
		printf $(bc -l <<< $1/1073741824)T
	elif [[ $(wc -m <<< $1) -gt 7 ]]; then
		printf $(bc -l <<< $1/1048576)G
	elif [[ $(wc -m <<< $1) -gt 4 ]]; then
		printf $(bc -l <<< $1/1024)M
	elif [[ $(wc -m <<< $1) -gt 1 ]]; then
		printf "$1 K"
	fi )
	printf $(echo $CalcResult | sed 's/^\./0./' | cut -c1-4 | sed 's/\.\$//' |sed 's/[ .]*$//' )
	# append prefix
	printf "$(echo $CalcResult | rev | cut -c1) \n"
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
get_filesystem_classes () {
	# get filesystemclass values
	FSLocalSystemListCalc=$(df -hTP | egrep $(echo $FSLocalSystems| tr " " "|") | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}')
	FSLocalStorageListCalc=$(df -hTP | egrep $( echo $FSLocalStorage| tr " " "|") | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}')
	if [[ -n $(grep Sailfish <<< $DetectedOS) ]]; then
		FSRemoteListCalc=$(df -hTP | egrep $(echo $FSRemote| tr " " "|") | grep -v alien | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}')
	else
		FSRemoteListCalc=$(df -hTP | egrep $(echo $FSRemote| tr " " "|") | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}')
	fi
	if [[ -n $FSLocalSystemListCalc ]]; then FSClassList=FSLocalSystemList ; FSClassSystem=true ;fi
	if [[ -n $FSLocalStorageListCalc ]]; then FSClassList=$(echo "$FSClassList" FSLocalStorageList) ; FSClassStorage=true ;fi
	if [[ -n $FSRemoteListCalc ]]; then FSClassList=$(echo "$FSClassList" FSRemoteList) ; FSClassRemote=true ;fi
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
calculate_summary_values () {
	# set storage class values
	for FSClass in $FSClassList ; do
		ColumnCounter=0
		# set column values
		for Column in Size Used Avail; do
			ColumnCounter=$(($ColumnCounter+1))
			# set varnames and calculate values in byte
			eval $(echo "$FSClass""$Column"Raw)=$(bc -l <<< $(eval echo '"'"$""$(eval echo "$FSClass"Calc)"'"' | awk -F " " '{printf "+" $'$ColumnCounter' }' | cut -c 2-1000)) 2>/dev/null
			# calculate SI prefix
			eval $(echo "$FSClass""$Column")=$(calculate_SI_prefix $(eval echo $(echo "$"$(echo "$FSClass""$Column"Raw))))
		done
		# caculate used percent for each filesystemclass
		eval $(echo "$FSClass"UsedPercent)=$(bc -l <<< $(eval echo '"'"$""$(eval echo "$FSClass"UsedRaw)"'"' / '"'"$""$(eval echo "$FSClass"SizeRaw)"'"' '"*"' 100) | cut -d "." -f1)%
	done
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
print_parser_list () {

   MountpointString=$(echo $@ | awk -F " " '{printf $7}'| cut -c1-$MaxMountpointLength)
   DeviceString=$(echo $@ | awk -F " " '{printf $1}'| cut -c1-$MaxDeviceLength)

   awk  '{ printf " %-"'"$MaxDeviceLength"'"s %10s %6s %6s %6s %5s %11s %-"'"$MaxMountpointLength"'"s\n", $1, $3, $4, $5, $6, $7, $9, $10 }' <<< "$DeviceString $@ $MountpointString"
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
print_graph_star () {
	for i in `seq 10 10 $GraphValue`; do
		printf "*"
	done
	printf "\n"
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
print_graph () {
	printf $ResetColor
	GraphValue=$(( $(echo "$1" | tr " " "\n" | grep "%" | sed 's/[^0-9]*//g' ) + $GraphRoundThreshold ))
	if   [[ $GraphValue -le $GraphThresholdLow ]]; then
		printf "[$(echo $(print_graph_star $GraphValue)---------- | cut -c1-10 )" | sed 's/\*/'$GraphColorLow'\*/' | sed 's/\-/'$ResetColor'\-/' && printf $ResetColor]
	elif [[ $GraphValue -le $GraphThresholdMid ]]; then
		printf "[$(echo $(print_graph_star $GraphValue)---------- | cut -c1-10 )" | sed 's/\*/'$GraphColorMid'\*/' | sed 's/\-/'$ResetColor'\-/' && printf $ResetColor]
	elif [[ $GraphValue -le $(( $GraphThresholdHigh + $GraphRoundThreshold )) ]]; then
		printf "[$(echo $(print_graph_star $GraphValue)---------- | cut -c1-10 )" | sed 's/\*/'$GraphColorHigh'\*/' | sed 's/\-/'$ResetColor'\-/' && printf $ResetColor]
	fi
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
print_output_line () {
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	for i in $1 ; do
		print_parser_list "$i $(print_graph $i)"
	done
	IFS=$SAVEIFS
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   start script   #############################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   check config   #############################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
 if   [[ -s $ConfigFile  ]] && [[ -z $(cat $ConfigFile | grep "Reconfigure=true\|CreateNewConfig=true") ]]; then
	# read config file
	source $ConfigFile

 elif [[ -s $ConfigFile  ]] && [[ -n $(cat $ConfigFile | grep "Reconfigure=true") ]]; then
	# read config and reconfigure
	source $ConfigFile
 	configure_dialog

 elif [[ ! -s $ConfigFile  ]] || [[ -n $(cat $ConfigFile | grep "CreateNewConfig=true") ]]; then
	# create new config file
	configure_dialog
 fi
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   check options   ############################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
 load_processing_vars
#-------------------------------------------------------------------------------------------------------------------------------------------------------
 get_filesystem_classes
#-------------------------------------------------------------------------------------------------------------------------------------------------------
 check_for_LAN_host
#-------------------------------------------------------------------------------------------------------------------------------------------------------

 case $1 in
	-h|--help|--version)	usage;;
	-m|--monochrome)	MonochromeOutput=true
				load_processing_vars;;
	-l|--listconfig) 	cat $ConfigFile
				exit ;;
	-c|--configure)		echo "CreateNewConfig=true" >> $ConfigFile
				$0
				exit;;
	-r|--reconfigure)	echo "Reconfigure=true" >> $ConfigFile
				$0
				exit;;
	-v|--verbose)		source $ConfigFile
				FSExclude="noneNonenone"
				load_processing_vars
				get_filesystem_classes;;
	-cfrp)			check_for_required_packages
				exit;;
	?*)			usage
				exit;;
 esac

#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   print output   #############################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------

 printf "$SeperatorLine\n"
 printf "$ColumnHeaderColor" && print_parser_list "$ColumnHeader"
 printf "$SeperatorLine\n"

 printf " MainSystem $FrameColor|$ResetColor\n"
 printf "$FrameColor------------+ $ResetColor\n"
 print_output_line "$FSLocalSystemList"
 printf "$SeperatorLine\n"

 if [[ -n $FSClassStorage ]]; then
	printf " Storage FileSystems $FrameColor|$ResetColor\n"
	printf "$FrameColor---------------------+$ResetColor\n"
	print_output_line "$FSLocalStorageList"
	printf "$SeperatorLine\n"
 fi

 if [[ -n $FSRemoveableList ]]; then
	printf " Removeable Drives $FrameColor|$ResetColor\n"
	printf "$FrameColor-------------------+$ResetColor\n"
	print_output_line "$FSRemoveableList"
	printf "$SeperatorLine\n"
 fi

 if [[ -n $FSRemoteListLAN ]]; then
	printf " Network shares (LAN) $FrameColor|$ResetColor\n"
	printf "$FrameColor----------------------+$ResetColor\n"
	print_output_line "$FSRemoteListLAN"
	printf "$SeperatorLine\n"
 fi

 if [[ -n $FSRemoteListWAN ]]; then
	printf " Network shares (WAN) $FrameColor|$ResetColor\n"
	printf "$FrameColor----------------------+$ResetColor\n"
	print_output_line "$FSRemoteListWAN"
	printf "$SeperatorLine\n"
 fi

#-------------------------------------------------------------------------------------------------------------------------------------------------------

exit 0

#-------------------------------------------------------------------------------------------------------------------------------------------------------

#TODO Summary vars for sections
# 2.3.5	 dynamic seperatorline width, monocrome output updated
# 2.3.4  code review, stringlenght processing moved to print_parser_list function, headline formated too, shrink column for compact output
# 2.3.3  add MaxDeviceLength= + MaxMountpointLength= dynamic
# 2.3.2  add MaxDeviceLength= + MaxMountpointLength= fixed config size
# 2.3.1  add MaxDeviceLength 
# 2.3.0  add FS exclude option / code review
# 2.2.0  add netcat packet to require packets
# 2.1.9  separate Network shares LAN/WAN
