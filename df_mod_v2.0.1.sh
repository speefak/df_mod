#!/bin/bash
# name          : df_mod_v2
# desciption    : show filesystem usage
# autor         : speefak
# licence       : (CC) BY-NC-SA
  VERSION=2.0.1
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   check config   #############################################
############################################################################################################

 ConfigFile=$HOME/.dff.cfg
 if [[ -s $ConfigFile  ]]; then
   # read config file
   source $ConfigFile
 else
   # create config file
   df -hT -x tmpfs
   printf "\n"
   read -e -p " Enter local filesystems (main system e.g. /dev/sda1 ...): " -i "$(df | grep -w "/" | cut -d " " -f1)" LocalFileSystemsSystems
   read -e -p " Enter local filesystems (storage e.g. sda5 sdb1 /home ...): " -i "/home" LocalFileSystemsStorage
   read -e -p " Enter remote  filesystems (e.g. fuse ssh smb ...): " -i "ssh fuse smb"  RemoteFileSystems
   read -e -p " Enter frame color ( default red ): " -i "1" FrameColor
   read -e -p " Enter column header color (default green): " -i "2" ColumnHeaderColor
   read -e -p " Enter bar color 0-59% (default green ): " -i "2" BarColorLow
   read -e -p " Enter bar color 60-79% (default yellow ): " -i "3" BarColorMid
   read -e -p " Enter bar color 80-100% (default red ): " -i "1" BarColorHigh

   printf "\n create configfile using following values: \n\n"

   printf " Local main filesystems:	$LocalFileSystemsSystems\n"
   printf " Local storage filesystems:	$LocalFileSystemsStorage\n"
   printf " Remote filesystems:		$RemoteFileSystems\n"
   printf " Frame color:			$FrameColor\n"
   printf " Column header color:		$ColumnHeaderColor\n"
   printf " Bar color 0-59%%:		$BarColorLow\n"
   printf " Bar color 60-79%%:		$BarColorMid\n"
   printf " Bar color 80-100%%:		$BarColorHigh\n"

   # write config file
   for i in LocalFileSystemsSystems LocalFileSystemsStorage RemoteFileSystems FrameColor ColumnHeaderColor BarColorLow BarColorMid BarColorHigh; do
     echo "$i=\""$(eval echo $(echo "$"$i)| tr "," "|" | tr " " "|")\" >> $ConfigFile
   done
   exit
 fi
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
# df output filter
 FileSystemLocalSystem=$(df -hl  --output=source,fstype,size,used,avail,pcent,target | egrep ''$LocalFileSystemsSystems'' | sed '/tmpfs/g' | tr ":" " " | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}')
 FileSystemLocalStorage=$(df -hl  --output=source,fstype,size,used,avail,pcent,target | egrep ''$LocalFileSystemsStorage'' | sed '/tmpfs/g' | tr ":" " " | awk -F " " '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}')
 FileSystemRemote=$(df -h  --output=source,fstype,size,used,avail,pcent,target | egrep ''$RemoteFileSystems'' | sed '/tmpfs/g' | tr ":" " " | awk -F " " '{print $1,$3,$4,$5,$6,$7,$8,$9}')

 ColumnHeader="System-Device FS-Type Size Used Avail Used% Mountpoint Used-Graph"
 SeperatorLine=$(echo $(tput setaf $FrameColor)"--------------------------------------------------------------------------------------------------"	$(tput sgr0))
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
###########################################   define functions   ###########################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
usage () {
cat << USAGE
dff version $VERSION to display disk usage.
Options are:
 -h, --help      display help
 -v, --version   display version
 -c, --color     disable color
 -s, --setup	 create configuration file

USAGE
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
check_for_monochrome_output () {
 if [[ -n $(echo $@ | grep -w "\-c") ]]; then
   FrameColor=7
   ColumnHeaderColor=7
   BarColorLow=7
   BarColorMid=7
   BarColorHigh=7
   SeperatorLine=$(echo $(tput setaf $FrameColor)"--------------------------------------------------------------------------------------------------" $(tput sgr0))
 fi
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
print_parser () {
	echo "$@" | awk -F " " '{printf " %-25s %10s %5s  %5s   %5s   %5s    %11s   %-20s \n", \
				$1, $2, $3, $4, $5, $6, $8, $7}'
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

 if   [[ $BarValue -lt  60 ]]; then
	printf "[$(echo  "$(print_graph_star $BarValue)" )" | sed 's/\*/'$(tput setaf $BarColorLow)\*'/' && tput sgr0 && print_graph_wildcard $BarValue
 elif [[ $BarValue -lt  80 ]]; then
	printf "[$(echo  "$(print_graph_star $BarValue)" )" | sed 's/\*/'$(tput setaf $BarColorMid)\*'/' && tput sgr0 && print_graph_wildcard $BarValue
 elif [[ $BarValue -lt  110 ]]; then
	printf "[$(echo  "$(print_graph_star $BarValue)" )" | sed 's/\*/'$(tput setaf $BarColorHigh)\*'/' && tput sgr0 && print_graph_wildcard $BarValue
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
 if   [[ $1 == -v || $1 == -h ]]; then
   usage
   exit
 elif [[ $1 == -s ]]; then
   rm $ConfigFile
   sleep 1
   $0
 fi
#-------------------------------------------------------------------------------------------------------------------------------------------------------
check_for_monochrome_output  "$@"
#-------------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   start script   #############################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------------------
 echo $SeperatorLine
 tput setaf $ColumnHeaderColor && print_parser "$ColumnHeader" $(tput sgr0)
 echo $SeperatorLine
 echo $(tput sgr0) "Main System "$(tput setaf $FrameColor)"|"
 echo  "-------------+" $(tput sgr0)
 print_output_line "$FileSystemLocalSystem" 
 echo $SeperatorLine
 echo $(tput sgr0) "Storage Filesystems" $(tput setaf $FrameColor)"|"
 echo "---------------------+"$(tput sgr0)
 print_output_line "$FileSystemLocalStorage" 
 echo $SeperatorLine
 echo $(tput sgr0) "Network shares / Removeable Medium" $(tput setaf $FrameColor)"|"	
 echo $(tput setaf $FrameColor)"------------------------------------+"$(tput sgr0)
 print_output_line "$FileSystemRemote"
 echo $SeperatorLine 

exit 0

