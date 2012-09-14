#!/bin/sh 
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or http://www.opensolaris.org/os/licensing.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#

#
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)ftp.auto.sh	1.3	08/04/22 SMI"
#

#*******************************************************************************
# usage()
# Print usage information if insufficient arguments are passed
#*******************************************************************************
usage() {

        echo "Usage: $0 "
        echo "    -r ftp_remote_int1,ftp_remote_int2"
        echo "    -s ftp_file_size_with_m|k|g "
        echo "    -t ftp_time_in_seconds"
        echo "    -P ftp_root_passwd "
        echo "    -m mailto "
        echo "    -p product "
        echo "    -e stop_on_err" 
        echo ""
}


#*******************************************************************************
#  setup_vars()
#  set the variable defaults and create log directories
#*******************************************************************************
setup_vars() {
    
        # set Logfiles and directories
        TESTNAME=`basename $0 .auto`

        LOGDIR="${STF_RESULTS}/tmp/${TESTNAME}"

        TMP_LOG_DIR="${STF_RESULTS}/tmp/${TESTNAME}_`date '+%H.%M.%S'`"
        mkdir -p $TMP_LOG_DIR

        LOGFILE="${TMP_LOG_DIR}/${TESTNAME}.sum.`date '+%y.%m.%d.%H.%M.%S'`"

        # Set defaults for variables
        REMOTE_INT=""
        FTP_SIZE=10m            # 10 megabytes
        FTP_TIME=3600           # 1 hour
        MAILTO='root@localhost' # local user
        STOP_ON_ERR=0           # disabled
        MAXWAIT=1200	# wait after ftp_time, 600 to 1200 due to 1gB/10Mb	

        # Store 0 (disabled) in a file called stopfile
        # If STOP_ON_ERR variable is enabled, this file will be
        # modified on encountering an error in ftp test, so that
        # all ftp processes can read this file and stop the test
        echo "0" >> ${STF_RESULTS}/tmp/stopfile$$

        # Check and see if a rc file exists for this tool
        if [ -f ./nic_ftp.rc ]; then
	        # Source in the rc file for all variables
	        . ./nic_ftp.rc
        fi
}


#*******************************************************************************
# process the commandline arguments
#*******************************************************************************
process_commandline() {

        # Grab command line parameters if any
        for i in $*; do
	        case $i in 
                    -r)  REMOTE_INT=$2
                         shift 2
                         ;;
                    -s)  FTP_SIZE=$2
                         shift 2
                         ;;
                    -t)  FTP_TIME=$2
                         shift 2
                         ;;
                    -P)  FTP_PASSWD=$2
                         shift 2
                         ;;
                    -m)  MAILTO=$2
                         shift 2
                         ;;
                    -p)  PRODUCT=$2
                         shift 2
                         ;;
	            -e)  STOP_ON_ERR=$2
		         shift 2
		         ;;
                    -h|-H|-help)  usage | tee -a $LOGFILE
		         exit
                         ;;
                    -*)  echo "$1 - Unrecognized parameter\n"
		         usage | tee -a $LOGFILE
		         exit
                         ;;
                esac
        done
}


#*******************************************************************************
# verify the mandatory parameters
#*******************************************************************************
verify_params() {

        # Verify mandatory input parameters - remote interface name for ftp
        if [ "X${REMOTE_INT}" = "X" ]; then
	        echo "FAILED: REMOTE_INT not defined" | tee -a $LOGFILE
                usage | tee -a $LOGFILE
	        report 1 "REMOTE_INT not defined"
                exit 255
        fi

        # Remove , from REMOTE_INT if multiple remote interfaces are specified
        cli=`echo $REMOTE_INT | sed 's/,/ /g'`
        REMOTE_INT=$cli

        # Make a copy of netrc file and Update it to allow ftp to our
        # client interfaces; Create file to be ftp'ed
        if [ `uname -s` = "SunOS" ]; then
                if [ -f ${STF_RESULTS}/tmp/.netrc ]; then
                        cp ${STF_RESULTS}/tmp/.netrc ${STF_RESULTS}/tmp/.netrc.orig
                fi
		mkdir -p ${STF_RESULTS}/tmp
                mkfile $FTP_SIZE ${STF_RESULTS}/tmp/file1
        elif  [ `uname -s` = "Linux" ]; then
                if [ -f ${STF_RESULTS}/tmp/.netrc ]; then
                        # in Linux root is /root not /
                        cp ${STF_RESULTS}/tmp/.netrc ${STF_RESULTS}/tmp/.netrc.orig
                fi
                # linux does not come with mkfile so use this local copy
		mkdir -p ${STF_RESULTS}/tmp
                ./Linux_mkfile $FTP_SIZE ${STF_RESULTS}/tmp/file1
        fi
}


#*******************************************************************************
# setup the systems for the ftp test
#*******************************************************************************
setup_ftp() {

        for client in $REMOTE_INT; do
                echo "Setting up client ${client}"
                host_os=`uname -s`
                remote_os=`rsh ${client} uname -s`

                # create the .netrc files
                if [ ${host_os} = "SunOS" ]; then
                        echo "machine $client login root password $FTP_PASSWD"\
                             >> ${STF_RESULTS}/tmp/.netrc
                        chmod 700 ${STF_RESULTS}/tmp/.netrc
                elif [ ${host_os} = "Linux" ]; then
                        echo "machine $client login root password $FTP_PASSWD"\
                             >> ${STF_RESULTS}/tmp/.netrc
                        chmod 700 ${STF_RESULTS}/tmp/.netrc
                fi

                # create the transfer files
                if [ ${remote_os} = "SunOS" ]; then
			rsh $client -l root "mkdir -p ${STF_RESULTS}/tmp"
                        rsh $client -l root "mkfile $FTP_SIZE ${STF_RESULTS}/tmp/file1"
                elif [ ${remote_os} = "Linux" ]; then
                        # client is linux. Linux doesn't come with mkfile so 
                        # copy it over
			rsh $client -l root "mkdir -p ${STF_RESULTS}/tmp"
                        rcp ./Linux_mkfile ${client}:${STF_RESULTS}/tmp
                        rsh $client -l root \
                                    "${STF_RESULTS}/tmp/Linux_mkfile $FTP_SIZE ${STF_RESULTS}/tmp/file1"
                fi
        done

}


#*******************************************************************************
#  run_ftp()
#
#  SUT process to fire of a thread for each ftp interface and monitor
# the running of ftp threads or just wait the run time
# run_ftp -> run_ftp_time -> myftp  to generate the FTP traffic
#*******************************************************************************
run_ftp() {

        LOCAL_HOST=`hostname`

        str="FTP test started at `date '+%y.%m.%d.%H.%M.%S'`"
        echo "${str}" | tee -a $LOGFILE
        echo  |tee -a $LOGFILE

        for client in $REMOTE_INT; do
                # create the client log and start the ftp test
                # client log contains the start time, finish time and 
                # number of transfers to that client
                # complete log contains the transfer details
                str="FTP test started with remote interface $client at "
                str="${str} `date '+%y.%m.%d.%H.%M.%S'`"
                client_log="${TMP_LOG_DIR}/${client}.log"
	        echo "${str}" | tee -a $client_log 

	        complete_log="$TMP_LOG_DIR/$LOCAL_HOST-$client.log."
                complete_log="${complete_log}`date '+%y.%m.%d.%H.%M.%S'`"
	        run_ftp_time $client $complete_log &
        done
   
        # Sleep until all clients finish ftp

        # Do not goto sleep for FTP_TIME with one sleep command
        # if STOP_ON_ERR is enabled and some ftp processes fail,
        # all other ftp processes may be stopped. Hence we have 
        # to constantly check to see if ftp processes stopped 
        # because of an error and wakeup if all ftp stopped.
        if [ $STOP_ON_ERR -eq 1 ]; then
	        rem_time=$FTP_TIME
    	        while [ `cat ${STF_RESULTS}/tmp/stopfile$$` -ne 1 -a $rem_time -gt 0 ]; do
    	                sleep 30
	                rem_time=`expr $rem_time - 30`
                done
        else
  	        sleep $FTP_TIME
        fi
}


#*******************************************************************************
#  run_ftp_time()
#
#  This is the subroutine that manages the ftp thread.  Each tread writes
# to it's own log file (client_log) that is checked at the end to verify
# success.  Threads run for FTP_TIME unless they fail.
#
#*******************************************************************************
run_ftp_time() {

	client=$1
        complete_log=$2
        client_log="${TMP_LOG_DIR}/${client}.log"
        curr_dir=${STF_SUITE}/tools/ftp/`isainfo -n`
        curr_time=`$curr_dir/calc_secs`
        end_time=`expr $curr_time + $FTP_TIME`

        # Initialize test completion to 0 percent
        # Next message will be printed out after 25% completion
        one_fourth=`expr $FTP_TIME / 4`
        completion=0
        compare_time=`expr $curr_time + $one_fourth`
        count=0
        numTransfers=0

        while [ `$curr_dir/calc_secs` -lt $end_time ] &&
              [ `cat ${STF_RESULTS}/tmp/stopfile$$` -eq 0 ]; do
	        myftp $client $complete_log

	        if [ $? -ne 0 ]; then
                        error="FTP error to remote interface $client"
                        error="${error} - `date '+%y.%m.%d.%H.%M.%S'`"
                        echo "${error}" >> $client_log
	                report 2 "$error"
	        fi

                # verify that both directions really tranfered
                count=`expr $count + 1`
                numTransfers=`grep -c "226 Transfer complete" $complete_log`
                if [ $numTransfers -ne `expr $count \* 2` ]; then
                        error="Number of transfers equals $numTransfers but "
                        error="${error} should be $count times 2"
                        echo "${error}" >> $client_log
	                report 2 "$error"
                fi


                # Print % completion of ftp test 
                if [ `$curr_dir/calc_secs` -ge $compare_time ]; then
                        while [ `$curr_dir/calc_secs` -ge $compare_time ]; do
	                        completion=`expr $completion + 25`
	                        compare_time=`expr $compare_time + $one_fourth`
                        done
                        if [ $completion -gt 100 ]; then
                                completion=100
                        fi
	                echo "${client}:FTP tests - ${completion}% completed..."
	        fi 
        done
	
        msg="FTP test completed with remote interface $client at"
        msg="${msg} `date '+%y.%m.%d.%H.%M.%S'`"
        echo "${msg}" | tee -a $client_log
        msg="FTP get/put $count files at $FTP_SIZE in $FTP_TIME sec on"
        msg="${msg}  interface $client"
        echo "${msg}" | tee -a $client_log
        exit 0
}


#*******************************************************************************
#  myftp()
#
#  Runs actual ftp commands
#*******************************************************************************
myftp() {

   ftp -n $1 << ! >>$2
user root $FTP_PASSWD
bin
ver
put ${STF_RESULTS}/tmp/file1 /dev/null
get ${STF_RESULTS}/tmp/file1 /dev/null
bye
!
   ftp_status=$?
   return $ftp_status
}


#*******************************************************************************
# saveResultToDatabase()
#
# This subroutine adds the capability for automatic uploading of test results
# into the nsn pv testmatrix
#*******************************************************************************
saveResultToDatabase() {

        # ${LOGFILE} is the full path the the results file
        # ${TITLE} is a string
        # ${STATUS} must be P or F
        # ${TEST_MATRIX_ID} is the passed database locator. a unsigned int

        # For NSN test database only
        if [ "X${TEST_MATRIX_ID}" != "X" ]; then
                if [ -f /suites/utils/TestMatrix/SaveTestResults.ksh ]; then
                        TITLE="${PRODUCT}:${TESTNAME} results on `hostname`"
                        /suites/utils/TestMatrix/SaveTestResults.ksh \
                                                        -f ${LOGFILE} \
                                                        -t ${TITLE}\
                                                        -p ${STATUS} \
                                                        -m ${TEST_MATRIX_ID}
                        if [ $? != 0 ]; then
                                echo "Upload of result failed"
                                echo "Test results not logged in database"
                        fi
                else
                        msg="/suites/utils/TestMatrix/SaveTestResults.ksh"
                        msg="${msg} does not exist"
                        echo "${msg}"
                        echo "Test results not logged in database"
                fi
        fi
}


#*******************************************************************************
# print the status of the test run
#*******************************************************************************
printStatus() {
      
        echo  | tee -a ${LOGFILE}
        echo "Setup Summary" | tee -a ${LOGFILE}
        echo "======================================" | tee -a ${LOGFILE}
        echo "PRODUCT      : ${PRODUCT}" | tee -a ${LOGFILE}
        echo "REMOTE_INT   : ${REMOTE_INT}" | tee -a ${LOGFILE}
        echo "FTP_SIZE     : ${FTP_SIZE}" | tee -a ${LOGFILE}
        echo "FTP_TIME     : ${FTP_TIME}" | tee -a ${LOGFILE}
        echo "STOP_ON_ERR  : ${STOP_ON_ERR}" | tee -a ${LOGFILE}
        echo  | tee -a ${LOGFILE}
        echo "FTP Status" | tee -a ${LOGFILE}
        echo "======================================" | tee -a ${LOGFILE}
        echo "${SUBJECT}" | tee -a ${LOGFILE}
}


#*******************************************************************************
# report()
#
# Decides the subject based on input parameter
# Emails result after test completes (success or failure)
# Usage : report EXIT_VALUE ERROR_INFO
#*******************************************************************************
report () {

        echo >> $LOGFILE
        echo $2 >> $LOGFILE

        # $1 could be 0 (Pass), 1 (Fail) or 2 (Aborted)
        case $1 in
	    0)  SUBJECT="PASSED"
                MAILSUB="${TESTNAME} for ${PRODUCT}: ${SUBJECT} - $2"
                printStatus
                if [ `uname -s` = "SunOS" ]; then
    	                cat $LOGFILE | mailx -s "${MAILSUB}" $MAILTO
                elif  [ `uname -s` = "Linux" ]; then
    	                cat $LOGFILE | mail -s "${MAILSUB}" $MAILTO
                fi
                STATUS='P'
                saveResultToDatabase
	        clean_ftp
		exit 0
	        ;;

	    1)  SUBJECT="FAILED"
                MAILSUB="${TESTNAME} for ${PRODUCT}: ${SUBJECT} - $2"
                printStatus
                if [ `uname -s` = "SunOS" ]; then
    	                cat $LOGFILE | mailx -s "${MAILSUB}" $MAILTO
                elif  [ `uname -s` = "Linux" ]; then
    	                cat $LOGFILE | mail -s "${MAILSUB}" $MAILTO
                fi
                STATUS='F'
                saveResultToDatabase
		exit 1
	        ;;

	    2)  SUBJECT="FAILED"
                # 2 is only called from the thread so the exit will only exit
                # the thread not the whole program
	        if [ $STOP_ON_ERR -eq 1 ]; then
		        echo "Stop on Error enabled."| tee -a $LOGFILE
                        echo "Stopping all ftp tests..\n" | tee -a $LOGFILE
		        # Modify the content of stopfile to 1 which means
		        # ftp processes should be stopped on reading this
                        # file 
		        rm ${STF_RESULTS}/tmp/stopfile$$
		        echo "1" > ${STF_RESULTS}/tmp/stopfile$$
		        exit $1
	        else
		        echo "Stop on Error disabled."
                        echo "Hence continuing tests..\n"
		        exit $1
	        fi
	        ;;
        esac
}


#*******************************************************************************
# wait for all processes to finish and verify that all did pass.  Report
# pass/fail
#*******************************************************************************
checkPassFail() {

        # wait for process to finish 
        numFtp=1
        timeWaited=0
        while [ $numFtp -gt 0 ] && [ $timeWaited -lt $MAXWAIT ]; do
                sleep 10
                timeWaited=`expr $timeWaited + 10`
                numFtp=`ps -e|grep ftp|grep -v ftp.auto|wc|awk '{print $1}'`
        done
        if [ $timeWaited -ge $MAXWAIT ]; then
                report 1 "FTP tests did not finish `date '+%y.%m.%d.%H.%M.%S'`"
        fi

        numPasses=0
        numClient=0
        for client in $REMOTE_INT; do
                client_log="${TMP_LOG_DIR}/${client}.log"
                echo "Results for Interface $client " >> $LOGFILE
                echo "---------------------------------------------" >> $LOGFILE
                cat $client_log >> $LOGFILE
                echo >> $LOGFILE
                pass=`grep -c completed $client_log`
                numPasses=`expr $numPasses + $pass`
                numClient=`expr $numClient + 1`
        done
        if [ $numPasses -ne $numClient ]; then
                report 1 "FTP tests failed `date '+%y.%m.%d.%H.%M.%S'`"
        else
                report 0 "FTP tests completed `date '+%y.%m.%d.%H.%M.%S'`"
        fi
}


#*******************************************************************************
#  clean_ftp()
#
#  Clean temp files created for ftp
#*******************************************************************************
clean_ftp() {

        # Copy back original .netrc file
        if [ `uname -s` = "SunOS" ]; then
		if [ -f ${STF_RESULTS}/tmp/.netrc.orig ]; then
                	cp ${STF_RESULTS}/tmp/.netrc.orig ${STF_RESULTS}/tmp/.netrc
		fi
        elif  [ `uname -s` = "Linux" ]; then
		if [ -f ${STF_RESULTS}/tmp/.netrc.orig ]; then
                	cp ${STF_RESULTS}/tmp/.netrc.orig ${STF_RESULTS}/tmp/.netrc
		fi
        fi

        # Copy logfiles to specified directory
        if [ ! -d $LOGDIR ]; then
	        mkdir -p $LOGDIR
        fi
        mv $TMP_LOG_DIR $LOGDIR

        rm -rf ${STF_RESULTS}/tmp/file1
        rm -rf ${STF_RESULTS}/tmp/stopfile$$

        # Clean up the clients
        for client in $REMOTE_INT; do
                host_os=`rsh ${client} uname -s`
                if [ ${host_os} = "SunOS" ]; then
                        rsh $client -l root rm -rf ${STF_RESULTS}/tmp/file1
                elif [ ${host_os} = "Linux" ]; then
                        rsh $client -l root rm -rf ${STF_RESULTS}/tmp/file1
                        # client is linux. Remove the copy of Linux_mkfile 
                        # we put there.
                        rsh $client -l root rm -rf ${STF_RESULTS}/tmp/Linux_mkfile
                fi
        done
}


#*******************************************************************************
# Main Program
#
#  Calls the subroutine to setup, run ftp, cleanup 
#*******************************************************************************
setup_vars
process_commandline $*
verify_params
setup_ftp
run_ftp 
checkPassFail
exit 0
 
