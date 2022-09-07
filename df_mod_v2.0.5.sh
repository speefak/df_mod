#!/bin/bash
# name          : df_mod_v2
# desciption    : show filesystem usage
# autor         : speefak
# licence       : (CC) BY-NC-SA
  VERSION=2.0.5
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   check config   #############################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
 ConfigFile=$HOME/.dff.cfg
 if 	[[ -s $ConfigFile  ]] && [[ -z $(cat $ConfigFile | grep "Reconfigure=true") ]]; then
	# read config file
	source $ConfigFile
 else
	# create config file
	df -hT -x tmpfs
	printf "\n"
	read -e -p " Enter local filesystems (main system e.g. /dev/sda1 ...): " -i "$(df | grep -w "/" | cut -d " " -f1)" FSLocalSystems
	read -e -p " Enter local filesystems (storage e.g. sda5 sdb1 /home ...): " -i "/home" FSLocalStorage
	read -e -p " Enter remote  filesystems (e.g. fuse ssh smb ...): " -i "ssh fuse smb"  FSRemote
	read -e -p " Enter sorting column number for FS => local systems: " -i "7" SortFSColumnSystem
	read -e -p " Enter sorting column number for FS => local storage: " -i "7"  SortFSColumnStorage
	read -e -p " Enter sorting column number for FS => remote: 	" -i "7"  SortFSColumnRemote
	read -e -p " Enter frame color ( default red ): " -i "1" FrameColor
	read -e -p " Enter column header color (default green): " -i "2" ColumnHeaderColor
	read -e -p " Enter bar range low % (default 0-59 ): 0-" -i "59" BarThresholdLow
	read -e -p " Enter bar range mid % (default 60-89 ): $(($(echo $BarThresholdLow | cut -d "-" -f2) +1 ))-" -i "89" BarThresholdMid
	BarThresholdHigh="100"
	echo	   " Enter bar range high % (default 90-100 ): $(($(echo $BarThresholdMid | cut -d "-" -f2) +1 ))-100"
	read -e -p " Enter bar color low $BarRangeLow% (default green ): " -i "2" BarColorLow
	read -e -p " Enter bar color mid $BarRangeMid% (default yellow ): " -i "3" BarColorMid
	read -e -p " Enter bar color high $BarRangeHigh% (default red ): " -i "1" BarColorHigh

	printf "\n create configfile with following values: \n\n"

	printf " Local filesystems:		$FSLocalSystems\n"
	printf " Local storage filesystems:	$FSLocalStorage\n"
	printf " Remote filesystems:		$FSRemote\n"
	printf " Sort FS columnSystem:		$SortFSColumnSystem\n"
	printf " Sort FS columnStorage:		$SortFSColumnStorage\n"
	printf " Sort FS columnRemote:		$SortFSColumnRemote\n"	
	printf " Frame color:			$FrameColor\n"
	printf " Column header color:		$ColumnHeaderColor\n"
	printf " Bar Threshold low:		$BarThresholdLow%%\n"
	printf " Bar Threshold mid:		$BarThresholdMid%%\n"
	printf " Bar Threshold high:		$BarThresholdHigh%%\n"
	printf " Bar color low: 		$BarColorLow\n"
	printf " Bar color mid: 		$BarColorMid\n"
	printf " Bar color high: 		$BarColorHigh\n"

	BarRangeLow=$(echo 0-$BarThresholdLow)
	BarRangeMid="$(($(echo $BarThresholdLow | cut -d "-" -f2) +1 ))-$BarThresholdMid"
	BarRangeHigh="$(($(echo $BarThresholdMid | cut -d "-" -f2) +1 ))-100"

	# check for existing config file
	if [[ -s $ConfigFile  ]]; then	
		read -e -p " overwrite existing configuration (y/n) " -i "y" OverwriteConfig
		if [[ $OverwriteConfig == [yY] ]]; then
			rm $ConfigFile
			printf "\n new configuration created\n"
		else
			printf "\n existing configuration :\n\n"
			sed -i '/Reconfigure=true/d'  $ConfigFile 
			cat $ConfigFile
			exit
		fi 
	fi

	# write config file
	for i in FSLocalSystems FSLocalStorage FSRemote FrameColor ColumnHeaderColor SortFSColumnSystem SortFSColumnStorage SortFSColumnRemote \
		 BarThresholdLow BarThresholdMid BarThresholdHigh BarRangeLow BarRangeMid BarRangeHigh BarColorLow BarColorMid BarColorHigh; do
		echo "$i=\""$(eval echo $(echo "$"$i)| tr "," "|" | tr " " "|")\" >> $ConfigFile
	done
	$0
	exit
 fi
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
# define colors
 FrameColor=$(tput setaf $FrameColor)
 ColumnHeaderColor=$(tput setaf $ColumnHeaderColor)
 BarColorLow=$(tput setaf $BarColorLow)
 BarColorMid=$(tput setaf $BarColorMid)
 BarColorHigh=$(tput setaf $BarColorHigh)
 ResetColor=$(tput sgr0)

# sort column filesystems
 FSLStorageSortColumn=7
 FSLSystemSortColumn=7
 FSRemoteSortColumn=7

#-------------------------------------------------------------------------------------------------------------------------------------------------------
# define/filter df output
 FileSystemLocalSystem=$(df -hl  --output=source,fstype,size,used,avail,pcent,target | \
			egrep ''$FSLocalSystems'' | sed '/tmpfs/g' | tr ":" " " | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnSystem )

 FileSystemLocalStorage=$(df -hl  --output=source,fstype,size,used,avail,pcent,target | \
			egrep ''$FSLocalStorage'' | sed '/tmpfs/g' | tr ":" " " | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnStorage )

 FileSystemRemote=$(df -h  --output=source,fstype,size,used,avail,pcent,target | \
			egrep ''$FSRemote'' | sed '/tmpfs/g' | tr ":" " " | awk -F " " '{print $1,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnRemote )

 ColumnHeader="System-Device FS-Type Size Used Avail Used% Mountpoint Used-Graph"
 SeperatorLine=$(echo $FrameColor"--------------------------------------------------------------------------------------------------$ResetColor"	)
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
 -c, --config	 	create configuration
USAGE
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
monochrome_output () {
 FrameColor=$(tput setaf 7)
 ColumnHeaderColor=$(tput setaf 7)
 BarColorLow=$(tput setaf 7)
 BarColorMid=$(tput setaf 7)
 BarColorHigh=$(tput setaf 7)
 SeperatorLine=$(echo $(tput setaf 7)"--------------------------------------------------------------------------------------------------" $(tput sgr0))
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
print_parser () {
 echo "$@" | awk -F " " '{printf " %-25s %10s %5s  %5s   %5s   %5s    %11s   %-20s \n", $1, $2, $3, $4, $5, $6, $8, $7}'
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
print_graph_star () {
 for i in `seq 1 10 $BarValue`; do
	printf "*"
 done
 printf "\n"
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
print_graph_wildcard () {
 for i in `seq $BarValue 10 90`; do
	printf "-"
 done
 printf "]\n"
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
print_graph () {
 BarValue=$(echo "$1" | tr " " "\n" | grep "%" | sed 's/[^0-9]*//g' )

 if   [[ $BarValue -le $BarThresholdLow ]]; then
	printf "[$(echo  "$(print_graph_star $BarValue)" )" | sed 's/\*/'$BarColorLow\*'/' && printf $ResetColor && print_graph_wildcard $BarValue
 elif [[ $BarValue -le $BarThresholdMid ]]; then
	printf "[$(echo  "$(print_graph_star $BarValue)" )" | sed 's/\*/'$BarColorMid\*'/' && printf $ResetColor && print_graph_wildcard $BarValue
 elif [[ $BarValue -le $BarThresholdHigh ]]; then
	printf "[$(echo  "$(print_graph_star $BarValue)" )" | sed 's/\*/'$BarColorHigh\*'/' && printf $ResetColor && print_graph_wildcard $BarValue
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
#############################################   check options   ############################################
############################################################################################################

 case $1 in
     -[hv])	usage
		exit;;
	-m)	monochrome_output;;
	-s) 	cat $ConfigFile
		exit ;;
	-c)	echo "Reconfigure=true" >> $ConfigFile
		$0
		exit;;
	?*)	usage
		exit;;
 esac

#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   start script   #############################################
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

