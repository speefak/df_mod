#!/bin/bash
# name          : df_mod.sh
# desciption    : show differing FS usage
# autor         : speefak (itoss@gmx.de)
# licence       : (CC) BY-NC-SA
  VERSION=2.1.6
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
Disk free frontend - display free disk space - version $VERSION
Options are:
 -h, --help      	display help
 -v, --version   	display version
 -m, --monochrome	disable color
 -s, --sumary		print column summary
 -l, --listconfig	show configuration
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
 printf "\n"																		# varname in configfile
 read -e -p " Enter local filesystems (main system e.g. /dev/sda1 ...): " 		-i "${FSLocalSystems:-$(df | grep -w "/" | cut -d " " -f1)}" 	FSLocalSystems
 read -e -p " Enter local storage filesystems (storage e.g. sda5 sdb1 /home ...): " 	-i "${FSLocalStorage:-/home}" 					FSLocalStorage
 read -e -p " Enter remote  FSs (e.g. fuse ssh smb ...): " 				-i "${FSRemote:-ssh fuse smb}"  				FSRemote
 read -e -p " Enter sorting column number for FS => local systems: " 			-i "${SortFSColumnSystem:-7}" 					SortFSColumnSystem
 read -e -p " Enter sorting column number for FS => local storage: " 			-i "${SortFSColumnStorage:-7}"  				SortFSColumnStorage
 read -e -p " Enter sorting column number for FS => remote storage: " 			-i "${SortFSColumnRemote:-7}"  					SortFSColumnRemote
 read -e -p " Enter frame color ( default red ): " 					-i "${FrameColor:-1}" 						FrameColor
 read -e -p " Enter column header color (default green): " 				-i "${ColumnHeaderColor:-2}" 					ColumnHeaderColor
 read -e -p " Enter column summary color (default green): " 				-i "${ColumnSumaryColor:-3}" 					ColumnSumaryColor
 read -e -p " Enter graph range low % (default 0-59): 0-" 				-i "${GraphThresholdLow:-59}" 					GraphThresholdLow
 read -e -p " Enter graph range mid % (default 60-89): $(($GraphThresholdLow +1 ))-"  	-i "${GraphThresholdMid:-89}" 					GraphThresholdMid
 read -e -p " Enter graph range high % (default 90-100): $(($GraphThresholdMid +1 ))-" 	-i "${GraphThresholdHigh:-100}" 				GraphThresholdHigh
 GraphRangeLow=$(echo 0-$GraphThresholdLow)
 GraphRangeMid="$(( $GraphThresholdLow +1 ))-$GraphThresholdMid"
 GraphRangeHigh="$(( $GraphThresholdMid +1 ))-100"
 read -e -p " Enter graph round threshold $GraphRoundThreshold (default 5): " 		-i "${GraphRoundThreshold:-5}" 					GraphRoundThreshold
 read -e -p " Enter graph color low $GraphRangeLow% (default green): " 			-i "${GraphColorLow:-2}" 					GraphColorLow
 read -e -p " Enter graph color mid $GraphRangeMid% (default yellow): " 		-i "${GraphColorMid:-3}" 					GraphColorMid
 read -e -p " Enter graph color high $GraphRangeHigh% (default red): " 			-i "${GraphColorHigh:-1}" 					GraphColorHigh
 read -e -p " Enter default column sumary output (enable|disable): " 			-i "${ColumnSumaryCalc:-disabled}" 				ColumnSumaryCalc

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
 ColumnSumaryColor=$(tput setaf $ColumnSumaryColor)
 GraphColorLow=$(tput setaf $GraphColorLow)
 GraphColorMid=$(tput setaf $GraphColorMid)
 GraphColorHigh=$(tput setaf $GraphColorHigh)
 ResetColor=$(tput sgr0)

 ColumnHeader="System-Device FS-Type Size Used Avail Used% Mountpoint Used-Graph"
 SeperatorLine=$(echo $FrameColor"--------------------------------------------------------------------------------------------------$ResetColor"	)

 # define/filter df output
 FSLocalSystemList=$(df -hl --output=source,fstype,size,used,avail,pcent,target | \
			egrep -w $(echo $FSLocalSystems| tr " " "|") | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnSystem )

 FSLocalStorageList=$(df -hl --output=source,fstype,size,used,avail,pcent,target | \
			egrep -w $(echo $FSLocalStorage| tr " " "|") | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnStorage )

 FSRemoveableList=$(df -h --output=source,fstype,size,used,avail,pcent,target -x tmpfs | sed '1,2d' | \
			egrep -v $(echo $FSLocalSystems $FSLocalStorage $FSRemote| tr " " "|") | tr ":" " " | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnStorage)

 FSRemoteList=$(df -h --output=source,fstype,size,used,avail,pcent,target | \
			egrep -w $(echo $FSRemote| tr " " "|")  | sed 's/:/ _/g' | awk -F " " '{print $1,$3,$4,$5,$6,$7,$8,$9}' | sort -u -k$SortFSColumnRemote )
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
calculate_SI_prefix () {
 CalcResult=$(	 if   [[ $(wc -m <<< $1) -gt 13 ]]; then 
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

 printf $(echo $CalcResult | sed 's/^\./0./' | cut -c1-4 | sed 's/\.\$//' |sed  's/[ .]*$//' )
 # append prefix 
 printf "$(echo $CalcResult | rev | cut -c1) \n"
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
get_filesystem_classes () {
 # get filesystemclass values 
 FSLocalSystemListCalc=$(df -l --output=size,used,avail,source,target,fstype | egrep $(echo $FSLocalSystems| tr " " "|") | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}')
 FSLocalStorageListCalc=$(df -l --output=size,used,avail,source,target,fstype | egrep $( echo $FSLocalStorage| tr " " "|") | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}')
 FSRemoteListCalc=$(df --output=size,used,avail,source,target,fstype | egrep $(echo $FSRemote| tr " " "|")  | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}')

 # check available filesystem classes and set parameter
 if [[ -n $FSLocalSystemListCalc ]]; then  	FSClassList=FSLocalSystemList				; FSClassSystem=true ;fi
 if [[ -n $FSLocalStorageListCalc ]]; then 	FSClassList=$(echo "$FSClassList" FSLocalStorageList) 	; FSClassStorage=true ;fi
 if [[ -n $FSRemoteListCalc ]]; then 		FSClassList=$(echo "$FSClassList" FSRemoteList) 	; FSClassRemote=true ;fi
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

 SummaryLineLocalSystem="$FSLocalSystemListSize $FSLocalSystemListUsed $FSLocalSystemListAvail $(echo $FSLocalSystemListUsedPercent | sed 's/%/%%/') $ResetColor $(print_graph "$FSLocalSystemListUsedPercent")"
 SummaryLineLocalStorage="$FSLocalStorageListSize $FSLocalStorageListUsed $FSLocalStorageListAvail $(echo $FSLocalStorageListUsedPercent | sed 's/%/%%/') $ResetColor $(print_graph "$FSLocalStorageListUsedPercent")"
 SummaryLineRemote="$FSRemoteListSize $FSRemoteListUsed $FSRemoteListAvail $(echo $FSRemoteListUsedPercent | sed 's/%/%%/') $ResetColor $(print_graph "$FSRemoteListUsedPercent")"
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
monochrome_output () {
 FrameColor=$(tput setaf 7)
 ColumnHeaderColor=$(tput setaf 7)
 ColumnSumaryColor=$(tput setaf 7)
 GraphColorLow=$(tput setaf 7)
 GraphColorMid=$(tput setaf 7)
 GraphColorHigh=$(tput setaf 7)
 SeperatorLine=$(echo $(tput setaf 7)"--------------------------------------------------------------------------------------------------" $(tput sgr0))
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
print_parser_list () {
 echo "$@" | awk -F " " '{printf " %-25s %10s %9s  %6s   %6s   %6s    %11s   %-20s \n", $1, $2, $3, $4, $5, $6, $8, $7}'
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
	printf "[$(echo $(echo "$(print_graph_star $GraphValue)" )---------- | cut -c1-10 )" | sed 's/\*/'$GraphColorLow'\*/' | sed 's/\-/'$ResetColor'\-/' && printf $ResetColor]
 elif [[ $GraphValue -le $GraphThresholdMid ]]; then
	printf "[$(echo $(echo "$(print_graph_star $GraphValue)" )---------- | cut -c1-10 )" | sed 's/\*/'$GraphColorMid'\*/' | sed 's/\-/'$ResetColor'\-/' && printf $ResetColor]
 elif [[ $GraphValue -le $(( $GraphThresholdHigh + $GraphRoundThreshold )) ]]; then
	printf "[$(echo $(echo "$(print_graph_star $GraphValue)" )---------- | cut -c1-10 )" | sed 's/\*/'$GraphColorHigh'\*/' | sed 's/\-/'$ResetColor'\-/' && printf $ResetColor]
 fi
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
print_output_line () {  
 SAVEIFS=$IFS
 IFS=$(echo -en "\n\b")
 # proccessing each filesystem input line
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
 case $1 in
     	-[hv]|--help|--version)	usage
				exit;;
	-m|--monochrome)	monochrome_output;;
	-s|--sumary)		calculate_summary_values
				PrintSummary=true;;
	-l|--listconfig) 	cat $ConfigFile
		exit ;;
	-c|--configure)		echo "CreateNewConfig=true" >> $ConfigFile
		$0
		exit;;
	-r|--reconfigure)	echo "Reconfigure=true" >> $ConfigFile
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
 printf "$ColumnHeaderColor" && print_parser_list "$ColumnHeader"
 printf "$SeperatorLine \n"

 printf " MainSystem $FrameColor|$ColumnSumaryColor $(echo $SummaryLineLocalSystem  | awk -F " " '{printf " %32s %7s %8s %9s %38s \n",$1, $2, $3, $4, $6}' ) $ResetColor\n"
 printf "$FrameColor------------+ $ResetColor\n"
 print_output_line "$FSLocalSystemList"
 printf "$SeperatorLine \n"

 if [[ -n $FSClassStorage ]]; then
  printf " Storage FileSystems $FrameColor|$ColumnSumaryColor $(echo $SummaryLineLocalStorage  | awk -F " " '{printf " %23s %7s %8s %9s %38s \n",$1, $2, $3, $4, $6}' ) $ResetColor\n"
  printf "$FrameColor---------------------+$ResetColor\n"
  print_output_line "$FSLocalStorageList"
  printf "$SeperatorLine \n"
 fi

 if [[ -n $FSRemoveableList ]]; then
  printf " Removeable Drives $FrameColor|$ColumnSumaryColor $(echo $SummaryLineRemote  | awk -F " " '{printf " %8s %7s %8s %9s %38s \n",$1, $2, $3, $4, $6}' ) $ResetColor\n"
  printf "$FrameColor-------------------+$ResetColor\n"
  print_output_line "$FSRemoveableList"
  printf "$SeperatorLine \n"
 fi

 if [[ -n $FSClassRemote ]]; then
  printf " Network shares $FrameColor|$ColumnSumaryColor $(echo $SummaryLineRemote  | awk -F " " '{printf " %8s %7s %8s %9s %38s \n",$1, $2, $3, $4, $6}' ) $ResetColor\n"
  printf "$FrameColor----------------+$ResetColor\n"
  print_output_line "$FSRemoteList"
  printf "$SeperatorLine \n"
 fi

exit 0

