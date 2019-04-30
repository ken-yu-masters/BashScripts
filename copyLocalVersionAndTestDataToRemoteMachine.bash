#!/bin/bash

# ----------------- all setting should be here -----------------
ExecutableFileLocationSetting="/y/Release_Developer"
TestCaseLocationSetting="/D/work/inputData/story_24676/C/Invision"
#NOTE!!! if there are config files (visoin.ini and so on)in above directories, BELOW will overwrite it. 
ConfigFileLocationSetting="/y"
#targets: first one is the master, all following are slaves
#        For example : VM_hosts=('\\VISION1' '\\VISION2' '\\VISION3' '\\VISION4')
#                      VM_hosts=('\\10.200.192.20' '\\10.200.192.21' '\\10.200.192.22' '\\10.200.192.23')
VM_hosts=('\\10.200.192.20' '\\10.200.192.21' '\\10.200.192.22' '\\10.200.192.23')
#VM_hosts=('\\10.200.192.20')
InVisionInstallLocationSetting="InVision"

WillRemoveExistingFilesBeforeCopy=0  #
WillCopyExecutableFiles=2            # 0 : off 1: incremental copy. 2: overwrite copy.
WillCopyTestCaseFiles=0              #
WillCopyConfigFiles=0                #
WillSetupDatabaseOnMaster=0          #

userNameSetting="hal"
passowrdSetting="hal"
# ----------------- -------------------------- -----------------

# color
txtblk='\033[0;30m' # Black - Regular
txtred='\033[0;31m' # Red
txtgrn='\033[0;32m' # Green
txtylw='\033[0;33m' # Yellow
txtblu='\033[0;34m' # Blue
txtpur='\033[0;35m' # Purple
txtcyn='\033[0;36m' # Cyan
txtwht='\033[0;37m' # White
bldblk='\033[1;30m' # Black - Bold
bldred='\033[1;31m' # Red
bldgrn='\033[1;32m' # Green
bldylw='\033[1;33m' # Yellow
bldblu='\033[1;34m' # Blue
bldpur='\033[1;35m' # Purple
bldcyn='\033[1;36m' # Cyan
bldwht='\033[1;37m' # White
unkblk='\033[4;30m' # Black - Underline
undred='\033[4;31m' # Red
undgrn='\033[4;32m' # Green
undylw='\033[4;33m' # Yellow
undblu='\033[4;34m' # Blue
undpur='\033[4;35m' # Purple
undcyn='\033[4;36m' # Cyan
undwht='\033[4;37m' # White
bakblk='\033[40m'   # Black - Background
bakred='\033[41m'   # Red
bakgrn='\033[42m'   # Green
bakylw='\033[43m'   # Yellow
bakblu='\033[44m'   # Blue
bakpur='\033[45m'   # Purple
bakcyn='\033[46m'   # Cyan
bakwht='\033[47m'   # White
txtrst='\033[0m'    # Text Reset

function chageServiceStatus ( )
{
	if [ $# -lt 3 ]; then
		echo "The number of positional parameter : $#"
		echo "Usage :"
		echo "chageServiceStatus targetMachine action serviceName "
		echo "For Exmaple:"
		echo "chageServiceStatus '\\10.200.192.20' start DataExportClientVision"
		return
	fi
	

	targetMachine="$1"
	action="$2"
	serviceName="$3"
	#debug
	echo "*** ${FUNCNAME} : $targetMachine $action $serviceName ***"
	#return
	
	#step 1: query
	status=$( sc $targetMachine query $serviceName |  grep STATE | awk '{print $NF}' )
	if [ $action == "query" ] ; then
		echo "   $status"
	elif [ $action == "start" ]; then
		retryTimes=0
		while [ $status != "RUNNING" ] && [ $retryTimes -le 3 ]; do
			output=$( sc $targetMachine start DataExportClientVision )
			sleep 3s
			status=$( sc $targetMachine query $serviceName |  grep STATE | awk '{print $NF}' )
			if [ $retryTimes -ne 0 ] ; then
				echo "      retry $retryTimes ..."
			fi
			let "retryTimes++"
		done
		echo "   $status"
	elif [ $action == "stop" ]; then
		retryTimes=0
		while [ $status != "STOPPED" ] && [ $retryTimes -le 3 ]; do
			output=$( sc $targetMachine stop DataExportClientVision )
			sleep 1s
			status=$( sc $targetMachine query $serviceName |  grep STATE | awk '{print $NF}' )
			if [ $retryTimes -ne 0 ] ; then
				echo "      retry $retryTimes ..."
			fi
			let "retryTimes++"
		done
		if [ $status != "STOPPED" ]; then
			#kill it.
			pid=$( sc $targetMachine queryex $serviceName |  grep PID | awk '{print $NF}' )
			if [ $pid -ne 0 ]; then
				cmd="taskkill.exe '//S' '$targetMachine' '//U' $userNameSetting '//P' $passowrdSetting '//PID' $pid"
				echo "   $cmd"
				eval $cmd
			fi
			sleep 1s
			status=$( sc $targetMachine query $serviceName |  grep STATE | awk '{print $NF}' )
		fi
		echo "   $status"
	else
		echo "   unsupported action : $action"
	fi

}

function copyFilesToRemoteMachine (   )
{
	if [ $# -lt 4 ]; then
		echo "The number of positional parameter : $#"
		return
	fi
	
	executableFileLocation="$1"
	testCaseLocation="$2"
	configFileLocation="$3"
	targetMachine="$4"
	targetLocation="$5"
	#debug
	echo "--------------------------------------------------------------------------------------------------------"
	echo "FUNCNAME               : ${FUNCNAME}"
	echo "executableFileLocation : $executableFileLocation"
	echo "testCaseLocation       : $testCaseLocation"
	echo "configFileLocation     : $configFileLocation"
	echo "targetMachine          : $targetMachine"
	echo "targetLocation         : $targetLocation"
	echo "--------------------------------------------------------------------------------------------------------"
	#return
	
	#establish new connections:
	targetMachineName=$( echo $targetMachine | tr -d '\\' )
	echo -e "${txtgrn}***Establish new connection to '$targetMachineName'${txtrst}"
	#clear old connection if there are
	#something like : net use '\\VISION1\IPC$' /delete
	cmd="NET USE '$targetMachine\\IPC\$' /delete > /dev/null"
	echo "   $cmd"
	output=$( eval $cmd )
	sleep 1s #wait for 1 second.
	#something like : net use '\\VISION1\IPC$' /USER:hal hal
	cmd="NET USE '$targetMachine\\IPC\$' /USER:$userNameSetting $passowrdSetting > /dev/null"
	echo "   $cmd"
	output=$( eval $cmd )
	sleep 1s #wait for 1 second.

	#kill vision
	echo -e "${txtgrn}***Stop running vision:${txtrst}"
	imageName="Vision.exe"
	#get the vision.exe PID
	echo "   get the vision.exe PID"
	cmd="tasklist.exe '//S' $targetMachineName '//U' $userNameSetting '//P' $passowrdSetting '//NH' '//FI' \"IMAGENAME eq $imageName\" | grep '$imageName' | awk '{print \$2}'"
	echo "   $cmd"
	PID=$( eval $cmd)
	regularExpression='^[0-9]+$'
	if [[ $PID =~  $regularExpression ]] ; then #PID must be a number
		echo -e "   Kill vision.exe ${txtgrn}PID : $PID${txtrst}."
		cmd="taskkill.exe '//S' $targetMachineName '//U' $userNameSetting '//P' $passowrdSetting '//T' '//FI' \"IMAGENAME eq $imageName\""
		echo "   $cmd"
		eval $cmd
		sleep 2s
	else
		echo "   Vision.exe has already been killed. Or cannot find the PID"
	fi
	
	#stop services
	echo -e "${txtgrn}***Stop services${txtrst}"
	chageServiceStatus $targetMachine stop DataExportClientVision
	chageServiceStatus $targetMachine stop DataExportClientSysMon
	chageServiceStatus $targetMachine stop SysMon

	destinationDirectory="$targetMachine/$targetLocation"

	#delete old files
	echo -e ${txtgrn}"***Delete old files"${txtrst}
	if [ $WillRemoveExistingFilesBeforeCopy -gt 0 ] ; then
		cmd="rm -rf '$destinationDirectory/'"'*'""
		echo "   $cmd"
		eval $cmd
	else
		echo -e "${txtylw}    Skip ...${txtrst}"
	fi
	
	#copy the executable files
	echo -e ${txtgrn}"***Copy executable files"${txtrst}
	#
	#RObocopy is copy command like rsync which supports incremental copy.
	#/E : copy child directories/files, even Empty directory. /S : copy child directories/files, but NOT empty directory
	#/PURGE : delete the directories/files in target which is not belong to source.
	#/MIR : mirror mode, == /E + /PURGE
	#/NJH : not printing header. /NJS : nor printing summery at end.
	#/NDL : not printing Direcotry List. /NFL : not printing File List.
	#/NS : not printing size. /NC : not printing category. 
	if [ $WillCopyExecutableFiles -eq 2 ] ; then
		cmd="cp -rf $executableFileLocation/. '$destinationDirectory'"
	else
		cmd="Robocopy.exe '$executableFileLocation/' '$destinationDirectory' '//E' '//NJH' '//NJS' '//NDL' '//NFL' '//NC' '//NS' '//XF' *.pdb *.lib *.ilk > /dev/null"
	fi
	if [ $WillCopyExecutableFiles -gt 0 ] ; then
		echo "   $cmd"
		eval $cmd
	else
		echo -e "${txtylw}    Skip ...${txtrst}"
	fi
	
	#prepare DataExport directory
	echo -e ${txtgrn}"*** prepare DataExport directory"${txtrst}
	if [ ! -d $destinationDirectory/DataExport ] ; then 
		mkdir $destinationDirectory/DataExport
	fi
	if [ ! -d $destinationDirectory/DataExport/Data ] ; then 
		mkdir $destinationDirectory/DataExport/Data
	fi
	if [ ! -d $destinationDirectory/DataExport/Logs ] ; then 
		mkdir $destinationDirectory/DataExport/Logs
	fi
	cp -rf $executableFileLocation/DataExportClient.* $destinationDirectory/DataExport
	cp -rf $executableFileLocation/boost*.dll $destinationDirectory/DataExport
	cp -rf $executableFileLocation/CrashGuard.dll $destinationDirectory/DataExport
	
	#copy the test case files
	echo -e ${txtgrn}"***Copy test case files"${txtrst}
	cmd="cp -rf $testCaseLocation/. '$destinationDirectory'"
	#cmd="Robocopy.exe '$testCaseLocation/' '$destinationDirectory' '//E' '//NJH' '//NJS' '//NDL' '//NFL' '//NC' '//NS' > /dev/null"
	if [ $WillCopyTestCaseFiles -gt 0 ] ; then
		echo "   $cmd"
		eval $cmd
	else
		echo -e "${txtylw}    Skip ...${txtrst}"
	fi
	
	#copy the configration files
	echo -e ${txtgrn}"*** copy the configration files"${txtrst}
	if [ $WillCopyConfigFiles -gt 0 ] ; then 
		#main config file : Vision.ini
		if [ -e "$testCaseLocation/Vision.ini" ] ; then
			cmd="cp -rf $VisionIniFileName  '$destinationDirectory/'"
			echo "   $cmd"
			eval $cmd
		else
			echo -e "${txtred}    CANNNOT FIND  Vision.ini ${txtrst}"
		fi
		#useful when checking invision version compatible
		cmd="cp -rf $configFileLocation/Version.txt  '$destinationDirectory/'"
		echo "   $cmd"
		eval $cmd
		#license
		cmd="cp -rf $configFileLocation/Features.xml '$destinationDirectory/'"
		echo "   $cmd"
		eval $cmd
		#which files need copy from master to salve
		cmd="cp -rf $configFileLocation/VisionFiles.cfg '$destinationDirectory/'"
		echo "   $cmd"
		eval $cmd
	else
		echo -e "${txtylw}    Skip ...${txtrst}"
	fi
	
	#start services
	echo -e "${txtgrn}***Strart services${txtrst}"
	chageServiceStatus $targetMachine start DataExportClientVision
	chageServiceStatus $targetMachine start DataExportClientSysMon
	chageServiceStatus $targetMachine start SysMon
	
	echo ""
}

function setupDataBaseOnRemoteMaster ( )
{
	if [ $# -lt 2  ]; then
		echo "The number of positional parameter : $#"
		return
	fi
	
	masterFullName="$1"
	testCaseLocation="$2"
	#debug
	echo "--------------------------------------------------------------------------------------------------------"
	echo "FUNCNAME               : ${FUNCNAME}"
	echo "masterFullName         : $masterFullName"
	echo "testCaseLocation       : $testCaseLocation"
	echo "--------------------------------------------------------------------------------------------------------"
	#return
	
	#find the Vision.ini
	if [ -e "$testCaseLocation/Vision.ini" ] ; then
		VisionIniFileName="$testCaseLocation/Vision.ini"
	#elif [ -e "$configFileLocation/Vision.ini" ] ; then
	#	VisionIniFileName="$configFileLocation/Vision.ini"
	else
		VisionIniFileName=""
	fi
	if [ $VisionIniFileName != "" ] ; then
		echo -e "    USE : ${txtgrn}$VisionIniFileName${txtrst}"
	else
		echo -e "${txtred}    CANNNOT FIND  $VisionIniFileName ${txtrst}"
		return
	fi
	
	#find the dump.sql
	sqlFileName="$testCaseLocation/Node1/dump.sql"
	if [ -e "$sqlFileName" ] ; then
			echo -e "    USE : ${txtgrn}$sqlFileName${txtrst}"
	else
		echo -e "${txtred}    CANNNOT FIND  $sqlFileName ${txtrst}"
		return
	fi
	#check DatabaseAddress is correct.
	cmd="cat $VisionIniFileName | grep DatabaseAddress | awk -F '=' '{print \$NF}' "
	serverNameInIni=$( eval $cmd )
	masterName=$( echo $masterFullName | tr -d '\\' )
	if [ $serverNameInIni == $masterName ] ; then
		echo -e "    master name in ini file : ${txtgrn}$serverNameInIni${txtrst}"
		echo    "                Matched with master name in script"
	else
		echo -e "    master name ${txtred}MISMATCH : ${txtrst}"
		echo -e "               init file : ${txtred}${serverNameInIni}${txtrst}"
		echo -e "                  script : ${txtred}${masterName}${txtrst}"
		return
	fi
	
	#check database Name
	cmd="cat $VisionIniFileName | grep DatabaseName= | awk -F '=' '{print \$NF}' "
	databaseNameInIni=$( eval $cmd )
	echo -e "   database name in ini file : ${txtgrn} $databaseNameInIni${txtrst}"
	
	#delete and create DB
	cmd="dropdb.exe -U postgres -h $serverNameInIni -w $databaseNameInIni"
	echo "   $cmd"
	eval $cmd
	cmd="createdb.exe -U postgres -h $serverNameInIni -w $databaseNameInIni"
	echo "   $cmd"
	eval $cmd

	#restore content from dump.sql
	cmd="psql.exe  -U postgres -h $serverNameInIni -d $databaseNameInIni < $sqlFileName"
	echo "   $cmd"
	output=$( eval $cmd )
}

#main() is here !!!!
for VM_NAME in ${VM_hosts[@]}; do
	cmd="copyFilesToRemoteMachine '$ExecutableFileLocationSetting' '$TestCaseLocationSetting' '$ConfigFileLocationSetting' '$VM_NAME' '$InVisionInstallLocationSetting'"
	#echo $cmd
	eval $cmd
done
if [ $WillSetupDatabaseOnMaster -gt 0 ] ; then
	setupDataBaseOnRemoteMaster ${VM_hosts[0]} $TestCaseLocationSetting
fi
echo "*** FINISHED"
