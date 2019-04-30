#!/bin/bash
#usage:
#goto test case directory(something like : /d/work/inputData/story_25104), make sure the test case directory's name is end with target process test case number.
#for exmaple :
#../importDumpSQLToDB.bash -z config20190429-121219.zip -a 1

# ----------------- all setting should be here -----------------
testCaseDirectory=`pwd`
configFileLocation="/y"
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

function importDumpSQLTODatabase ( )
{
	if [ $# -lt 1 ]; then
		echo "The number of positional parameter : $#"
		return
	fi
	testCaseLocation="$1"
	#debug
	echo "--------------------------------------------------------------------------------------------------------"
	echo "FUNCNAME               : ${FUNCNAME}"
	echo "testCaseLocation       : $testCaseLocation"
	echo "--------------------------------------------------------------------------------------------------------"
	#return
	
	
	#find the Vision.ini
	if [ -e "$testCaseLocation/Vision.ini" ] ; then
		VisionIniFileName="$testCaseLocation/Vision.ini"
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
	cmd="hostname.exe"
	localHostName=$( eval $cmd )
	if [ $serverNameInIni == "localhost" ] || [ $serverNameInIni == $localHostName ] ; then
		echo -e "    server name in ini file : ${txtgrn}$serverNameInIni${txtrst}"
		echo    "                Matched with local host name."
	else
		echo -e "    server name ${txtred}MISMATCH : ${txtrst}"
		echo -e "               init file : ${txtred}${serverNameInIni}${txtrst}"
		echo -e "               localhost : ${txtred}${localHostName}${txtrst}"
		return
	fi
	
	#check database Name
	cmd="cat $VisionIniFileName | grep DatabaseName= | awk -F '=' '{print \$NF}' "
	databaseNameInIni=$( eval $cmd )
	echo -e "   database name in ini file : ${txtgrn} $databaseNameInIni${txtrst}"
	
	#delete and create DB
	echo -e "   ${txtgrn}delete and create DB${txtrst}"
	cmd="dropdb.exe -U postgres -h $serverNameInIni -w $databaseNameInIni"
	echo "      $cmd"
	eval $cmd
	cmd="createdb.exe -U postgres -h $serverNameInIni -w $databaseNameInIni"
	echo "      $cmd"
	eval $cmd
	
	#restore content from dump.sql
	echo -e "   ${txtgrn}restore content from dump.sql${txtrst}"
	cmd="psql.exe  -U postgres -h $serverNameInIni -d $databaseNameInIni < $sqlFileName"
	echo "      $cmd"
	output=$( eval $cmd )
	
	#update current computer name
	echo -e "   ${txtgrn}update current computer name to database${txtrst}"
	tableName="Nodes"
	columnName="szComputerName"
	cmd="psql.exe -U postgres -h localhost -d $databaseNameInIni -c  \"UPDATE \\\"$tableName\\\" SET \\\"$columnName\\\" = '$localHostName' WHERE \\\"blMaster\\\" = 't' \""
	echo "      $cmd"
	eval $cmd
	
	#
	#Change version to 19.0, dbMigrate will update it
	#
	#echo -e "   ${txtgrn}Change version to 19.0, dbMigrate will update it${txtrst}"
	#cmd="psql.exe -U postgres -h localhost -d $databaseNameInIni -c  \"UPDATE \\\"Version\\\" SET \\\"MajorNumber\\\"=19, \\\"MinorNumber\\\"=0 \" "
	#echo "      $cmd"
	#eval $cmd
	#cmd="psql.exe -U postgres -h localhost -d $databaseNameInIni -c  \"SELECT \\\"MajorNumber\\\", \\\"MinorNumber\\\" FROM \\\"Version\\\" \" "
	#echo "      $cmd"
	#eval $cmd
	
	#clean cache, OR it exception will NOT show
	#echo -e "   ${txtgrn}Clean Cached directory${txtrst}"
	#cmd='rm -rf Cached/*'
	#echo "      $cmd"
	#eval $cmd
}

#../importDumpSQLToDB.bash -z config20190429-121219.zip -a 1
for ((i = 1; i < $#; i=i+2 )); do
	eval "option=\${${i}}"
	eval "argument=\${$((i+1))}"
	#debug:
	#echo "option : $option"
	#echo "argument : $argument"
	if [ "$option" == "--zipFile" ] || [ "$option" == "-z" ]; then
		zipFile=$argument
		echo -e "   ${txtgrn}Extracting files from : ${zipFile} ${txtrst}"
		cmd="7z.exe x $zipFile -aoa  > /dev/null"
		echo "   $cmd"
		eval $cmd
	elif [ "$option" == "--autoFixDatabaseAddresInIniFile" ] || [ "$option" == "-a" ]; then
		if [ $argument ]; then
			VisionIniFileName="Vision.ini"
			newDatabaseAddress="localhost"
			echo -e "   ${txtgrn}Replacing database address to ${newDatabaseAddress} in : ${VisionIniFileName} ${txtrst}"
			cmd="sed -i '/DatabaseAddress=/cDatabaseAddress=${newDatabaseAddress}' ${VisionIniFileName}"
			echo "   $cmd"
			eval $cmd
			sleep 1s
			#TargetProcessCaseNumber is the numbers of last part of current directory
			cmd="pwd | grep -o '[0-9][0-9]*'"
			echo "   $cmd"
			TargetProcessCaseNumber=`eval $cmd`
			#
			newDatabaseName="invision_${TargetProcessCaseNumber}"
			echo -e "   ${txtgrn}Replacing database name to ${newDatabaseName} in : ${VisionIniFileName} ${txtrst}"
			cmd="sed -i '/DatabaseName=/cDatabaseName=${newDatabaseName}' ${VisionIniFileName}"
			echo "   $cmd"
			eval $cmd
		fi
	else
		echo -e "{txtred}Unsupported option : ${option}{txtrst}"
		exit
	fi
done

#useful when checking invision version compatible
cmd="cp -rf $configFileLocation/Version.txt  '$testCaseDirectory/'"
echo "   $cmd"
eval $cmd

#license
if test -f "$testCaseDirectory/Features.xml"; then
	echo -e "   ${txtylw}SKIP.${txtrst} Features.xml exists in $testCaseDirectory."
else
	cmd="cp -rf $configFileLocation/Features.xml '$testCaseDirectory/'"
	echo "   $cmd"
	eval $cmd
fi

#which files need copy from master to salve
cmd="cp -rf $configFileLocation/VisionFiles.cfg '$testCaseDirectory/'"
echo "   $cmd"
eval $cmd
importDumpSQLTODatabase $testCaseDirectory

echo -e "***${txtgrn}FINISHED${txtrst}***"