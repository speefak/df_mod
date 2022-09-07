#!/bin/bash
# name          : df_mod_v2
# desciption    : show filesystem usage
# autor         : speefak
# licence       : (CC) BY-NC-SA
  VERSION=2.1.0
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
 ConfigFile=$HOME/.dff.cfg
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
###########################################   define functions   ###########################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
usage () {
cat << USAGE
Disk Free Frontend - display free disk space - version $VERSION
Options are:
 -h, --help      	display help
 -v, --version   	display version
 -m, --monochrome	disable color
 -s, --show config	show configuration
 -c, --configure 	create new configuration
 -r, --reconfigure 	reconfigure configuration
USAGE
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
configure_dialog () {

# create config file
 ConfigParameterList=$(cat $0 | grep -A50 "configure_dialog () {" | grep "read -e -p \" Enter" | awk -F " " '{print $NF}')

# display Var input prompt and default value, enter/edit value
 df -hT -x tmpfs
 printf "\n"
 read -e -p " Enter local filesystems (main system e.g. /dev/sda1 ...): " 	-i "${FSLocalSystems:-$(df | grep -w "/" | cut -d " " -f1)}" 	FSLocalSystems
 read -e -p " Enter local filesystems (storage e.g. sda5 sdb1 /home ...): " 	-i "${FSLocalStorage:-/home}" 					FSLocalStorage
 read -e -p " Enter remote  filesystems (e.g. fuse ssh smb ...): " 		-i "${FSRemote:-ssh fuse smb}"  				FSRemote
 read -e -p " Enter sorting column number for FS => local systems: " 		-i "${SortFSColumnSystem:-7}" 					SortFSColumnSystem
 read -e -p " Enter sorting column number for FS => local storage: " 		-i "${SortFSColumnStorage:-7}"  				SortFSColumnStorage
 read -e -p " Enter sorting column number for FS => remote storage: " 		-i "${SortFSColumnRemote:-7}"  					SortFSColumnRemote
 read -e -p " Enter frame color ( default red ): " 				-i "${FrameColor:-1}" 						FrameColor
 read -e -p " Enter column header color (default green): " 			-i "${ColumnHeaderColor:-2}" 					ColumnHeaderColor
 read -e -p " Enter graph range low % (default 0-59): 0-" 			-i "${GraphThresholdLow:-59}" 					GraphThresholdLow
 read -e -p " Enter graph range mid % (default 60-89): $(($(echo $GraphThresholdLow | cut -d "-" -f2) +1 ))-" -i "${GraphThresholdMid:-89}" 	GraphThresholdMid
 GraphThresholdHigh="100"
 GraphRangeLow=$(echo 0-$GraphThresholdLow)
 GraphRangeMid="$(($(echo $GraphThresholdLow | cut -d "-" -f2) +1 ))-$GraphThresholdMid"
 GraphRangeHigh="$(($(echo $GraphThresholdMid | cut -d "-" -f2) +1 ))-100"
 echo	    " Enter graph range high % (default 90-100): $(($(echo $GraphThresholdMid | cut -d "-" -f2) +1 ))-100"
 read -e -p " Enter graph round value $GraphRoundValue (default 5): " 		-i "${GraphRoundValue:-5}" 					GraphRoundValue
 read -e -p " Enter graph color low $GraphRangeLow% (default green): " 		-i "${GraphColorLow:-2}" 					GraphColorLow
 read -e -p " Enter graph color mid $GraphRangeMid% (default yellow): " 	-i "${GraphColorMid:-3}" 					GraphColorMid
 read -e -p " Enter graph color high $GraphRangeHigh% (default red): " 		-i "${GraphColorHigh:-1}" 					GraphColorHigh

 # print new Vars
 printf "\n new configuration values: \n\n"
 for i in $ConfigParameterList; do
	echo " $i=\""$(eval echo $(echo "$"$i))\" 
 done

 # check for existing config file
 if [[ -s $ConfigFile  ]]; then
	printf "\n"	
	read -e -p " overwrite existing configuration (y/n) " -i "y" OverwriteConfig
	if [[ $OverwriteConfig == [yY] ]]; then
		rm $ConfigFile		
	else
		sed -i '/Reconfigure=true/d'  $ConfigFile
		sed -i '/CreateNewConfig=true/d'  $ConfigFile 
		printf "\n existing configuration :\n\n"
		cat $ConfigFile
		exit
	fi 
 fi

 # write Vars to config file
 for i in $ConfigParameterList; do
	echo "$i=\""$(eval echo $(echo "$"$i))\" >> $ConfigFile
 done

 printf "\n configuration saved in: $ConfigFile\n"

 $0
 exit
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
load_processing_vars () {
# define colors
 FrameColor=$(tput setaf $FrameColor)
 ColumnHeaderColor=$(tput setaf $ColumnHeaderColor)
 GraphColorLow=$(tput setaf $GraphColorLow)
 GraphColorMid=$(tput setaf $GraphColorMid)
 GraphColorHigh=$(tput setaf $GraphColorHigh)
 ResetColor=$(tput sgr0)

#-------------------------------------------------------------------------------------------------------------------------------------------------------
# define/filter df output
 FileSystemLocalSystem=$(df -hl  --output=source,fstype,size,used,avail,pcent,target | \
			egrep ''$(echo $FSLocalSystems| tr " " "|")'' | sed '/tmpfs/g' | tr ":" " " | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnSystem )z

 FileSystemLocalStorage=$(df -hl  --output=source,fstype,size,used,avail,pcent,target | \
			egrep ''$(echo $FSLocalStorage| tr " " "|")'' | sed '/tmpfs/g' | tr ":" " " | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnStorage )

 FileSystemRemote=$(df -h  --output=source,fstype,size,used,avail,pcent,target | \
			egrep ''$(echo $FSRemote| tr " " "|")'' | sed '/tmpfs/g' | tr ":" " " | awk -F " " '{print $1,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnRemote )

 ColumnHeader="System-Device FS-Type Size Used Avail Used% Mountpoint Used-Graph"
 SeperatorLine=$(echo $FrameColor"--------------------------------------------------------------------------------------------------$ResetColor"	)
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
monochrome_output () {
 FrameColor=$(tput setaf 7)
 ColumnHeaderColor=$(tput setaf 7)
 GraphColorLow=$(tput setaf 7)
 GraphColorMid=$(tput setaf 7)
 GraphColorHigh=$(tput setaf 7)
 SeperatorLine=$(echo $(tput setaf 7)"--------------------------------------------------------------------------------------------------" $(tput sgr0))
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
print_parser () {
 echo "$@" | awk -F " " '{printf " %-25s %10s %5s  %5s   %5s   %5s    %11s   %-20s \n", $1, $2, $3, $4, $5, $6, $8, $7}'
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

 GraphValue=$(( $(echo "$1" | tr " " "\n" | grep "%" | sed 's/[^0-9]*//g' ) + $GraphRoundValue ))
 if   [[ $GraphValue -le $GraphThresholdLow ]]; then
	printf "[$(echo $(echo "$(print_graph_star $GraphValue)" )---------- | cut -c1-10 )" | sed 's/\*/'$GraphColorLow'\*/' | sed 's/\-/'$ResetColor'\-/' && printf $ResetColor]
 elif [[ $GraphValue -le $GraphThresholdMid ]]; then
	printf "[$(echo $(echo "$(print_graph_star $GraphValue)" )---------- | cut -c1-10 )" | sed 's/\*/'$GraphColorMid'\*/' | sed 's/\-/'$ResetColor'\-/' && printf $ResetColor]
 elif [[ $GraphValue -le $(( $GraphThresholdHigh + $GraphRoundValue )) ]]; then
	printf "[$(echo $(echo "$(print_graph_star $GraphValue)" )---------- | cut -c1-10 )" | sed 's/\*/'$GraphColorHigh'\*/' | sed 's/\-/'$ResetColor'\-/' && printf $ResetColor]
 fi
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
print_output_line () {
 SAVEIFS=$IFS
 IFS=$(echo -en "\n\b")
 for i in $1 ; do
	print_parser "$i $(print_graph $i)"
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
 case $1 in
     -[hv])	usage
		exit;;
	-m)	monochrome_output;;
	-s) 	cat $ConfigFile
		exit ;;
	-c)	echo "CreateNewConfig=true" >> $ConfigFile
		$0
		exit;;
	-r)	echo "Reconfigure=true" >> $ConfigFile
		$0
		exit;;
	?*)	usage
		exit;;
 esac

#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   print output   #############################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
 printf "$SeperatorLine \n"
 printf "$ColumnHeaderColor" && print_parser "$ColumnHeader"
 printf "$SeperatorLine \n"
 printf "$ResetColor Main System $FrameColor|\n"
 printf "$FrameColor-------------+ $ResetColor\n"
 print_output_line "$FileSystemLocalSystem"
 printf "$SeperatorLine \n"
 printf "$ResetColor Storage Filesystems $FrameColor|\n"
 printf "$FrameColor---------------------+$ResetColor\n"
 print_output_line "$FileSystemLocalStorage"
 printf "$SeperatorLine \n"
 printf "$ResetColor Network shares / Removeable Medium $FrameColor|\n"
 printf "$FrameColor------------------------------------+$ResetColor\n"
 print_output_line "$FileSystemRemote"
 printf "$SeperatorLine \n"

exit 0


