#!/bin/sh
# 
# Copyright (c) 2016, Search Solution Corporation. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions are met:
# 
#   * Redistributions of source code must retain the above copyright notice, 
#     this list of conditions and the following disclaimer.
# 
#   * Redistributions in binary form must reproduce the above copyright 
#     notice, this list of conditions and the following disclaimer in 
#     the documentation and/or other materials provided with the distribution.
# 
#   * Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products 
#     derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, 
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE 
# USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
#

# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
scriptPath=$(dirname "$SCRIPT")

svnuser="please_set_username"
svnpassword="please_set_password"
svn st --username $svnuser --password $svnpassword -u ${scriptPath}/file_core_issue.sh >temp.log
sed -i "/Status against revision/d" temp.log

svn st --username $svnuser --password $svnpassword -u ${scriptPath}/gdb_core.sh >temp1.log
sed -i "/Status against revision/d" temp1.log

if [ `cat temp.log|wc -l` -ne 0 ] || [ `cat temp1.log|wc -l` -ne 0 ]
then
    svn diff --username $svnuser --password $svnpassword ${scriptPath}/file_core_issue.sh
    svn diff --username $svnuser --password $svnpassword ${scriptPath}/gdb_core.sh
    rm -rf temp.log temp1.log
    echo "file_core_issue.sh or gdb_core.sh are not the newest, do you want to continue?"
    echo "please input yes or no"
    read answer
    case $answer in
       [nN]) exit;;
         no) exit;;
       [yY]) echo "continue ...";;
        yes) echo "continue ...";;
        *) exit;;
    esac
fi
rm -rf temp.log temp1.log

corepath=""
allinfo=""

corelocation=""
dblocation=""
errloglocation=""
rm -rf makedir.sh move.sh
touch move.sh

build=`cubrid_rel`
build=${build%(*}
build=${build#*(}
build=`echo $build|sed "s/)//"`
os=""
aos=`uname -a`
if [ `echo $aos| grep Linux|wc -l` -eq 1 ]
then
    os="Linux"
elif [ `echo $aos| grep CYGWIN_NT|wc -l` -eq 1 ]
then
   os="Windows_NT"
fi
if [ `echo $aos| grep _64|wc -l` -eq 1 ]
then
   os=`echo "${os} 64bit"`
else
   os=`echo "${os} 32bit"`
fi

if [ `echo "$os"|grep Linux|wc -l` -eq 1 ]
then
    ip=`/sbin/ifconfig|grep "inet addr:"|grep -v "127.0.0.1"|awk -F: '{print $2}'|sed 's/ .*//g'|head -1`
else
    ip=`ipconfig|grep "IPv4 Address"|awk -F: '{print $2}'|head -1`
fi
testserver="`whoami`@$ip"
password="please_set_password"

function usage
{
    exec_name=$(basename $0)
    cat <<CCQQTT
    usage: sh file_core_issue.sh -c core-path -d db-volume [-e -m|-s ]
    [-c core-path]   : required, core file path and name, eg: xxx/xx/core.123
    [-d db-volume]   : required, it is db-volume path or dbname or path/dbname, if only given dbname, get it from $CUBRID/database
    [-e error-log]   : optional, eg: /home/xdbms/CUBRID/log, if not given, get it from $CUBRID/log
    [-m]             : optional, it is used for master information
    [-s]             : optional, it is used for slave information
    [-l CUBRIDSUS-XXX]: exclusive, add CUBRIDSUS-XXX to readme.txt and register it to database, the registering info comes from template.txt
    [-v]             : optional, move the related files to archive file, the default operation is copy
    [-f f1 f2 ...]   : optional, move other related files to archive file, eg: -f path/file1 path/core.*
CCQQTT
    exit 1
}

function format_core()
{
    line=`grep -n 'Core was generated by' $1 |awk -F: '{print $1}'`
    line=`expr $line - 1`
    sed "1, $line d" $1
}

# to generate move.sh, do "mv ..." after all information is collected successfully
function move()
{
  if [ `grep "$1 " move.sh|wc -l` -eq 0 ]
  then
    if [ $ismove == "true" ]
    then
        echo "mv $1 $2" >>move.sh
    else
        echo "cp -r $1 $2" >>move.sh
    fi
  fi
}

coreFile=""
errorlog=""
dbvolume=""
server=""
ismove="false"
isf=0

version=`cubrid_rel|grep CUBRID|sed 's/).*$//g'|sed 's/^.*(//g'`
filename=${version}_`date "+%Y%m%d-%H%M%S"`
while [ $# -ne 0 ]; do
        case $1 in
                -h)
                    isf=0
                    usage
                    ;;
                -f)
                    isf=1
                    shift
                    if [ "$1" != "" ]
                    then
                        if [ -f $1 ] || [ -d $1 ]
                        then
                            move $1 $HOME/do_not_delete_core/${filename}
                        fi 
                    fi
                    ;;
                -c)
                    isf=0
                    shift
                    coreFile="$1"
                    ;;
                -d)
                    isf=0
                    shift
                    dbvolume="$1"
                    ;;
                -e)
                    isf=0
                    shift
                    errorlog="$1"
                    ;;
                -v)
                    isf=0
                    ismove="true"
                    ;;
                -m)
                    isf=0
                    if [ "${server}" == "" ]
                    then
                        server="master"
                    else
                        echo "master and slave can not appear simultaneously"
                        exit
                    fi
                   ;;
                -s)
                    isf=0
                    if [ "${server}" == "" ]
                    then
                        server="slave"
                    else
                        echo "master and slave can not appear simultaneously"
                        exit
                    fi
                   ;;
                -l)
                    isf=0
                    shift
                    issuenum="$1"
                    if [ `echo ${issuenum}|grep "CUBRIDSUS-[0-9][0-9][0-9][0-9][0-9][0-9]*"|wc -l` -eq 0 ]
                    then
                        echo "issue number isn't right, it should be like CUBRIDSUS-16212"
                        exit
                    else
                        echo "Are you sure to register information from template.txt as the following?"
                        grep "do_not_delete_core" template.txt
                        echo "Please input yes or no"
                        read answer
                        case $answer in
                            [nN]) exit;;
                            no) exit;; 
                            [yY]) echo "register ...";;
                            yes) echo "register ...";;
                        esac
                       # Save issue number, core stack and BTS issue key
                       score=`grep 'Core Location' template.txt |sed 's;\*Core Location:\* ;;g'`
                       if [ `echo $score|wc -l` -eq 1 ]
                       then
                            sh ${scriptPath}/analyzer.sh $score -s $issuenum
                       fi
                       # delete file
                       dpath=`grep 'DB-Volume Location:' template.txt|sed 's;\*DB-Volume Location:\*;;g'`
                       rpath=`echo ${dpath%/*}`
                       rm -rf $rpath
                       
                       # add issue number in readme
                       fname=`echo ${rpath##*/}`
                       echo "${fname}.tar.gz  $issuenum" >>$HOME/do_not_delete_core/readme.txt
                       exit
                    fi
                   ;;
                *)
                   if [ $isf -eq 0 ]
                   then
                       usage
                   else
                       if [ "$1" != "" ]
                       then
                           if [ -f $1 ] || [ -d $1 ]
                           then
                               move $1 $HOME/do_not_delete_core/${filename}
                           fi
                       fi
                   fi
                   ;;
        esac
        shift
done
if [ "${coreFile}" == "" ] && [ "${server}" == "" ]
then
    echo "Error: core file is a must"
    usage
    exit
fi

if [ "${dbvolume}" == "" ]
then
    echo "Error: db-volume is a must"
    usage
    exit
fi


function colorecho()
{
    echo -e "\033[1;32m ${1} \033[0m"
}

# to generate makedir.sh, do "mkdir ..." after all information is collected successfully
function makedir()
{
    echo "mkdir -p $1" >>makedir.sh
}

# move core file
corename=""
if [ "${coreFile}" != "" ]
then
    move $coreFile $HOME/do_not_delete_core/${filename}
    corename=`basename $coreFile`
fi

#move error log
errorlog=`echo $errorlog|sed 's;/$;;g'`
if [ "${errorlog}" == "" ]
then
    # if not defined, log is copied from $CUBRID/log
    colorecho "Notice: error log would be gotten from $CUBRID/log"
    move $CUBRID/log $HOME/do_not_delete_core/${filename}
else
    # move the given log to $HOME/do_not_delete_core
    logname=`basename $errorlog`
    if [ "${logname}" == "log" ]
    then
        move $errorlog $HOME/do_not_delete_core/${filename}
    else
        makedir $HOME/do_not_delete_core/${filename}/log
        move $errorlog $HOME/do_not_delete_core/${filename}/log
    fi
fi

# move db-volume
dbvolume=`echo $dbvolume|sed 's;/$;;g'`
dbname=`basename $dbvolume`
if [ "${dbname}" == "${dbvolume}" ]
then
    # give dbname without path, it is gotten from databases.txt
    dbdir=`grep ${dbname} $CUBRID/databases/databases.txt|awk '{print $2}'`
    colorecho "Notice: db-volumn would be gotten from $dbdir"
    # database is created directly under $CUBRID/databases
    makedir $HOME/do_not_delete_core/${filename}/${dbname}
    move  "${dbdir}/*${dbname}*" $HOME/do_not_delete_core/${filename}/${dbname}
    move  ${dbdir}/lob  $HOME/do_not_delete_core/${filename}/${dbname}
else
    # give path and dbname
    if [ -d ${dbvolume} ]
    then
        # there is dbname folder
        move  $dbvolume $HOME/do_not_delete_core/${filename}
    else
        # there isn't dbname folder
        makedir $HOME/do_not_delete_core/${filename}/${dbname}
        move  "${dbvolume%/*}/*${dbname}*" $HOME/do_not_delete_core/${filename}/${dbname}
        move  ${dbvolume%/*}/lob $HOME/do_not_delete_core/${filename}/${dbname}
    fi
fi

function log
{
    echo "$1" >>template.txt
}

echo "" >template.txt
log "*Test Build:* ${build}"
log "*Test OS:* ${os}" 
log "" 
log "*Description:*"

log "" 
log "*Repro Steps:*" 
log "1. sh XXX.sh" 
log "2. case svn address" 
log "3. write the code where the core is thrown if possible" 

log "*Core Files:*"
log "{code}"
for x in `cat move.sh |grep "core\.[0-9]"|sed 's/^cp -r //'|sed 's/^mv //'|awk '{print $1}'`
do
    message=`file $x`
    echo ${message}
    echo ${message##*/} >>template.txt
done
log "{code}"

if [ "${coreFile}" != "" ]
then
    log "" 
    log "*Call Stack Info:*"
    log "$corename" 
    log "{code}"
    coreerr=0
    echo "bt full" >command.txt
    echo "quit" >>command.txt
    sh ${scriptPath}/gdb_core.sh "${coreFile}" "command.txt" "core.info" >/dev/null
    
    # check correctness of core info
    if [ `grep "[0-9 x a-f]* * in * ??*" core.info|wc -l` -gt 0 ] 
    then
        colorecho "Error: CUBRID version isn't consistent with core file, please modify core info in template.txt"
        coreerr=1
    fi
    
    # core info is right, present it
    if [ $coreerr -eq 0 ]
    then
        format_core core.info >tmp
        # if core info is too long, use "bt" instead of "bt full"
        if [ `cat tmp|wc -l` -gt 50000 ]
        then
            colorecho "Notice: Please attach core.info to bts issue"
            echo "bt" >command.txt
            echo "quit" >>command.txt
            sh ${scriptPath}/gdb_core.sh ${coreFile} "command.txt" "core1.info" >/dev/null
            format_core core1.info >tmp
            rm core1.info
        fi
        cat tmp >>template.txt
        log ""
    fi
    log "{code}" 
fi

log ""
if [ "${server}" == "master" ]
then
    log '{color:red}*Master Info*{color}'
elif [ "${server}" == "slave" ]
then
    log '{color:red}*Slave Info*{color}'
fi
log "*Test Server:*"
log "user@IP: ${testserver}"
log "pwd: ${password}"
log ""

log "*All Info:*" 
log "${testserver}:${HOME}/do_not_delete_core/${filename}.tar.gz"
log "pwd: ${password}"
if [ "${coreFile}" != "" ]
then
    log "*Core Location:* $HOME/do_not_delete_core/${filename}/${corename}"
fi
log "*DB-Volume Location:* $HOME/do_not_delete_core/${filename}/${dbname}"
log "*Error Log Location*: $HOME/do_not_delete_core/${filename}/log"

# move the log
if [ ! -d $HOME/do_not_delete_core ]
then
    makedir $HOME/do_not_delete_core
fi
makedir $HOME/do_not_delete_core/${filename}

sh makedir.sh
sh move.sh

cd ${HOME}/do_not_delete_core
echo "tar -zcvf ${filename}.tar.gz ${filename}"
tar -zcvf ${filename}.tar.gz ${filename} >/dev/null
#echo "${filename}.tar.gz | CUBRIDSUS-XXXXX" >>$HOME/do_not_delete_core/readme.txt

colorecho "Notice: please read information from template.txt to file bug"
colorecho "Notice: db-volumn/core/log are archived in $HOME/do_not_delete_core/${filename}.tar.gz"
colorecho "Notice: Please save core status by sh file_core_issue.sh -l CUBRIDSUS-XXX"
#colorecho "Notice: Please register core (sh analyzer.sh -s ${filename}/${corename} CUBRIDSUS-XXX)"
#colorecho "Notice: After registering core file, please remove ${filename}"
#colorecho "Notice: Please modify CUBRIDSUS-XXXXX to actual issue number in $HOME/do_not_delete_core/readme.txt"

rm -rf temp tmp error.tmp 
