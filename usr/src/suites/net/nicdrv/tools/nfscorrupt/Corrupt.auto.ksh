#!/usr/bin/ksh -p
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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)Corrupt.auto.ksh	1.5	09/03/04 SMI"
#

################################################################################
# Copyright:   2005 by Sun Microsystems, Inc. All Rights Reserved.
# Purpose:     Check for corruption across NFS mounts via network interfaces
# Usage:       Corrupt.auto
#                      -c  "client_int1,client_int2,client_intN"
#                      -s  "server_int1,server_int2,server_intN"
#                      -n  "sessions per port"
#                      -t  "time in seconds to run"
#                      -d  "direction of traffic rx|tx|bi"
#                      -e  "first.last@sun.com"
#                      -p  "Product"
#                      -m  "mount protocol tcp|udp|rma"
#                      -r  "run on error  yes|no"
#
# ENVs will take from following in order:
#              1. Command line options
#              2. .Corruptrc file
#
# File:	       Corrupt.auto
# Rev:         1.26
# Author:      Gerald Gibson <gerald.gibson@sun.com>
# Source file: .Corruptrc
# Sample Source file:
#                      SERVER_INT="server_int1,server_int2"
#                      CLIENT_INT="client1_int1,client1_int2"
#                      MAILTO="root@localhost"
#                      PRODUCT="Cassini 1.44"
#                      SESSIONS="1"
#                      RUN_ON_ERROR="no"
#                      TRAFFIC_TYPE="bi"
#                      PROTO="tcp"
#                      TIME="3600"
#
################################################################################


set_defaults() {
        # calculated/static vars
        PROG=$(basename $0); 
	PRINTF=/usr/bin/printf
	DF=/usr/bin/df
        TESTNAME=$(basename $0 .auto)
        HOSTNAME=$(uname -n)
        DFSTAB='/etc/dfs/dfstab'  # solaris version
        EXPORTS='/etc/exports'    # linux version of dfstab
        CURDIR=$(pwd)
        LOGDIR="${STF_RESULTS}/tmp/${TESTNAME}"
        LOGFILE="${LOGDIR}/${TESTNAME}".log.$(date '+%Y-%m-%d_%H:%M:%S')
        SOURCEFILE="$CURDIR/.${TESTNAME}rc"
        MAXFILE=124000           # max file size from testcorrupt.c
        MAXWAIT=900              # max time to wait after end time for threads 
                                 # to finish
        WAITINT=30               # check every ? seconds to verify threads are 
                                 # finished

        # must pass vars to run default to '' also in .Corruptrc
        CLIENT_INT=''
        MAILTO='no'
        PRODUCT=''
        PROTO=''
        RUN_ON_ERROR=''
        SERVER_INT=''
        SESSIONS=''
        STATUS=''
        TEST_MATRIX_ID=''
        TIME=''
        TRAFFIC_TYPE=''

        # create the log dir if needed 
        # This is done here since errors are logged here so it needs done early
        if [[ ! -e "${LOGDIR}" ]]; then
		mkdir -p "$LOGDIR"
        fi
}


load_rc_file() {
        # source in the .Corruptrc if it exists
        if [[ -f $SOURCEFILE ]]; then
                . ${SOURCEFILE}

                # remove comma's from comma seperated lists
                SERVER_INT=$(print $SERVER_INT | sed 's/,/ /g');
                CLIENT_INT=$(print $CLIENT_INT | sed 's/,/ /g');
                CLIENT=$(print $CLIENT | sed 's/,/ /g');
        fi

}


usage () {
        $PRINTF "Usage: $0\n";
        $PRINTF "        -c  \"client_int1,client_int2,client_intN\"\n"
        $PRINTF "        -s  \"server_int1,server_int2,server_intN\"\n"
        $PRINTF "        -n  \"sessions per port\"\n"
        $PRINTF "        -t  \"time in seconds to run\"\n"
        $PRINTF "        -d  \"direction of traffic rx|tx|bi\"\n"
        $PRINTF "        -e  \"first.last@sun.com\"\n"
        $PRINTF "        -p  \"Product\"\n"
        $PRINTF "        -m  \"mount protocol udp|tcp|rdma\"\n"
        $PRINTF "        -r  \"run on error  yes|no\"\n"
        exit 8
}


process_commandline() {
        args=$*

        # stuff all multi words with a pattern so getopts is not confused
        # the pattern is '#@#' which is no a likely sequence
        args=$($PRINTF "${args}\n" | sed 's/ /#@#/g')
        args=$($PRINTF "${args}\n" | sed 's/#@#-/ -/g')
        args=$($PRINTF "${args}\n" | sed 's/-\([a-z]\)#@#/-\1 /g')

        while getopts :c:e:m:p:r:s:n:t:d: arguments $args; do
                case $arguments in
                        c) CLIENT_INT=$OPTARG
                           CLIENT_INT=$(print $CLIENT_INT | sed 's/,/ /g');
                           ;;
                        e) MAILTO=$OPTARG
                           MAILTO=$(print $MAILTO | sed 's/#@#/,/g');
                           ;;
                        m) PROTO=$OPTARG
                           ;;
                        p) PRODUCT=$OPTARG
                           PRODUCT=$(print $PRODUCT | sed 's/#@#/ /g');
                           ;;
                        r) RUN_ON_ERROR=$OPTARG
                           ;;
                        s) SERVER_INT=$OPTARG
                           SERVER_INT=$(print $SERVER_INT | sed 's/,/ /g');
                           ;;
                        n) SESSIONS=$OPTARG
                           ;;
                        t) TIME=$OPTARG
                           ;;
                        d) TRAFFIC_TYPE=$OPTARG
                           ;;
                        \?) usage
                           ;;
                esac
        done
}


verify_options() {
        # the following options are manditory options that come from either
        # the command line or rc file.  They are not derived or defaulted
        # so they must be set or we exit.

        if [[ "X${CLIENT_INT}" == "X" ]]; then
                print "FAILED: CLIENT_INT not set" | tee -a ${LOGFILE}
                usage
                exit 1
        fi

        if [[ "X${MAILTO}" == "X" ]]; then
                print "FAILED: MAILTO not set" | tee -a ${LOGFILE}
                usage
                exit 1
        fi

        if [[ "X${PRODUCT}" == "X" ]]; then
                print "FAILED: PRODUCT not set" | tee -a ${LOGFILE}
                usage
                exit 1
        fi

        if [[ "X${PROTO}" == "X" ]]; then
                print "FAILED: PROTO not set" | tee -a ${LOGFILE}
                usage
                exit 1
        fi

        if [[ $PROTO != @(udp|tcp|rdma) ]]; then
                print "FAILED: PROTO be udp,tcp,rdma" | tee -a ${LOGFILE}
                usage
                exit 1
        fi

        if [[ "X${RUN_ON_ERROR}" == "X" ]]; then
                print "FAILED: RUN_ON_ERROR not set" | tee -a ${LOGFILE}
                usage
                exit 1
        fi

        if [[ $RUN_ON_ERROR != @(yes|no) ]]; then
                print "FAILED: RUN_ON_ERROR be yes or no" | tee -a ${LOGFILE}
                usage
                exit 1
        fi

        if [[ "X${RUN_ON_ERROR}" == "X" ]]; then
                print "FAILED: RUN_ON_ERROR not set" | tee -a ${LOGFILE}
                usage
                exit 1
        fi

        if [[ "X${SERVER_INT}" == "X" ]]; then
                print "FAILED: SERVER_INT not set" | tee -a ${LOGFILE}
                usage
                exit 1
        fi

        if [[ "X${SESSIONS}" == "X" ]]; then
                print "FAILED: SESSIONS not set" | tee -a ${LOGFILE}
                usage
                exit 1
        fi

        if [[ "X${TIME}" == "X" ]]; then
                print "FAILED: TIME not set" | tee -a ${LOGFILE}
                usage
                exit 1
        fi

        if [[ "X${TRAFFIC_TYPE}" == "X" ]]; then
                print "FAILED: TRAFFIC_TYPE not set" | tee -a ${LOGFILE}
                usage
                exit 1
        fi

        if [[ $TRAFFIC_TYPE != @(rx|tx|bi) ]]; then
                print "FAILED: TRAFFIC_TYPE must be rx,tx,bi" \
                        | tee -a ${LOGFILE}
                usage
                exit 1
        fi

        # make sure the number of client int match the number of server int
        (( num_client_int = ( $($PRINTF "$CLIENT_INT"|awk '{print --NF}') + 1 ) ))
        (( num_server_int = ( $($PRINTF "$SERVER_INT"|awk '{print --NF}') + 1 ) ))
        if (( $num_client_int != $num_server_int )); then
                msg="FAILED: Number of servers doesn't match number of clients"
                print "${msg}" | tee -a ${LOGFILE}
                usage
                exit 1
        fi
}


clean_after_crash() {
        # if this program crashed or was exited mount point would be left
        # remove them before we start

        $PRINTF "Cleaning any old mounts"

        # make sure all testcorrupt instances are killed
        pkill testcorrupt

        # remove old client mounts
        last_clt=''
        for clt in $CLIENT_INT; do
                # timesaver don't process the same client twice
                clt_host=$(rsh ${clt} hostname)
                if [[ $? != 0 ]]; then
                        print "Could not access ${clt}"
                        exit 9
                fi
                if [[ ${last_clt} == ${clt_host} ]]; then
                        $PRINTF " ."
                        continue
                fi
                last_clt=${clt_host}

                # make sure all testcorrupt instances are killed
                rsh ${clt} "pkill testcorrupt"

                # remove the mount and mount point
                mnt_List=$(rsh ${clt} mount |egrep mnt.*_[0-9]|awk '{print $1}')
                for mount in $mnt_List; do
                        rsh ${clt} "umount -f ${mount}"
                        if [[ $? != 0 ]]; then
                                print "Could not unmount ${mount} on ${clt}"
                                exit 9
                        fi
                        rsh ${clt} "rm -rf ${mount}"
                done

                # remove the export dir
                exp_List=$(rsh ${clt} ls /export|egrep .*_[0-9]|awk '{print $1}')
                for dir in $exp_List; do
                        rsh ${clt} "rm -rf /export/${dir}"
                done

                $PRINTF " ."
        done

        # remove the servers mount and mount point
        mnt_List=$(mount |egrep mnt.*_[0-9]|awk '{print $1}')
        for mount in $mnt_List; do
                umount -f ${mount}
                if [[ $? != 0 ]]; then
                        print "Could not unmount ${mount} on SUT"
                        exit 9
                fi
                rm -rf ${mount}
        done

        # remove the servers export dir
        exp_List=$(ls /export|egrep .*_[0-9]|awk '{print $1}')
        for dir in $exp_List; do
                rm -rf "/export/${dir}"
        done
        $PRINTF " ."

        # remove any old tmp status files
        rm -f /tmp/Corrupt_*

        $PRINTF " DONE\n"
}


check_disk_space () {
        set -A hosts
        set -A k_req

        $PRINTF "Checking disk space"

        
	# check clients only if tx or bi
        if [[ $TRAFFIC_TYPE != "rx" ]]; then
                # Log in to each client and get the hostname.  The hostname 
                # goes into a array $hosts[] that contains all the unique 
                # hosts.  This array defines buckets for totals of disk space 
                # needed.  These totals are kept by a seperate array $k_req[] 
                # which hold the totals in kilobytes for each unique host. The 
                # disk space required for the host[N] is k_req[N]
                #
                i=0
                for clt in $CLIENT_INT; do
                        hostname=$(rsh $clt "hostname")
                        index=0
                        while (( $index <= $i )); do
                                if [[ ${hosts[$index]} == ${hostname} ]]; then
                                        k_req[$index]=$(( ${k_req[$index]} +
                                                   ( ${MAXFILE} * $SESSIONS ) ))
                                        break
                                fi
                                if (( $index == $i )); then
                                        hosts[$i]=${hostname}
                                        k_req[$i]=$(( ${MAXFILE} * $SESSIONS ))
                                        i=$(( $i + 1 ))
                                        break
                                fi
                                index=$(( $index + 1 ))
                        done
                        $PRINTF " ."
                done

                # The arrays are now loaded with host and required disk space. 
                # Check the free space on each host and check against the 
                # required disk space.
                i=0
                for host in ${hosts[*]}; do
			# Check the host alive
			ping $host
			if [[ $? != 0 ]]; then
				# In nicdrv, we needn't check the diskspace,
				# because it has been done in checkenv before.
				$PRINTF " cannot access $host, skip checking.\n"
				return 1
			fi
                        (( k_avail = $(rsh $host $DF -b / | grep -v Filesystem | \
			    awk '{print $2}') ))
                        if (( ${k_req[${i}]} > ${k_avail} )); then
                                msg="$host needs ${k_req[${i}]}k ${k_avail}k"
                                msg="${msg} available"
                                print "ERROR: ${msg}"
                                exit 8
                        fi
                        i=$(( $i + 1 ))
                        $PRINTF " ."
                done
        fi

	# check server only if rx or bi
        if [[ $TRAFFIC_TYPE != "tx" ]]; then
                # check server diskspace. All the diskspace is only on this 
                # host so space req = max file size * number of clients * 
                # number of sessions
               
                (( num_clients = ( $($PRINTF "$CLIENT_INT" | \
                                    awk '{print --NF}') + 1 ) ))
                (( k_req_server =  ${MAXFILE} * ${num_clients} * ${SESSIONS} ))
                (( k_avail = $($DF -b / | grep -v Filesystem | awk '{print $2}') ))
                host=$(hostname)

                if (( ${k_req_server} > ${k_avail} )); then
                        msg="$host needs ${k_req_server}k ${k_avail}k"
                        msg="${msg} available"
                        print "ERROR: ${msg}"
                        exit 8
                fi
                $PRINTF " ."
        fi
        $PRINTF " DONE\n"
}


distribute_binary() {
        $PRINTF "Distributing the test binary";

        # the OS dependent C binary is located in arch_OS dir
        # distribute the binary on to the clients
        last_clt=''
	for clt in $CLIENT_INT; do
                # timesaver don't process the same client twice
                clt_host=$(rsh ${clt} hostname)
                if [[ ${last_clt} == ${clt_host} ]]; then
                        $PRINTF " ."
                        continue
                fi
                last_clt=${clt_host}

                # rcp the binary to the client
                arch=$(rsh $clt "uname -p")
                OS=$(rsh $clt "uname -s")
		BIN_DIR=$(rsh $clt "isainfo -n")
		BIN_FILE=${STF_SUITE}/tools/nfscorrupt/${BIN_DIR}/testcorrupt
        	if [[ -f "${BIN_FILE}" ]]; then
			rcp "${BIN_FILE}" "${clt}:/tmp"
			rsh ${clt} "chmod 755 /tmp/testcorrupt"
        	else
                	$PRINTF "Unsupported OS, \
				please try stf_build on peer machine\n"
                	exit 8
        	fi
                $PRINTF " ."
        done

        # distribute the binary to the server
        arch=$(uname -p)
        OS=$(uname -s)
	BIN_DIR=$(isainfo -n)
	BIN_FILE=${STF_SUITE}/tools/nfscorrupt/${BIN_DIR}/testcorrupt
        if [[ -f "${BIN_FILE}" ]]; then
                cp "${BIN_FILE}" /tmp
                chmod 755 /tmp/testcorrupt
        else
                $PRINTF "Unsupported OS Exiting\n"
                exit 8
        fi
        $PRINTF " ."
        $PRINTF " DONE\n"
}


setup_nfs_Solaris() {
        clt_nfs=$1
	num_nfs=$2
	local=$3
        if [ $local -ne 1 ]; then
		rsh ${clt_nfs} "shareall -F nfs"
                # configure a remote host
		ret=$(rsh ${clt_nfs} "grep -c \"share -F nfs /export/${clt_nfs}_${num_nfs}\" $DFSTAB")
                if (( ! $ret )); then
                        rsh $clt_nfs "echo \"share -F nfs /export/${clt_nfs}_${num_nfs}\" >> ${DFSTAB}"
                fi
        else
		shareall -F nfs
                # configure the local host
                if (( ! $(grep -c "share -F nfs /export/${clt_nfs}_${num_nfs}" $DFSTAB) )); then
                        echo "share -F nfs /export/${clt_nfs}_${num_nfs}" >> ${DFSTAB}
                fi
        fi
}


setup_nfs_Linux() {
        clt_nfs=$1
        num_nfs=$2
        local=$3
        if [  $local -ne 1 ]; then
                # configure a remote host
                if (( ! $(rsh ${clt_nfs} "grep -c \
			'/export (rw)' ${EXPORTS}") )); then
                        # linux.  Must run nfs restart in backgroud otherwise
                        # it won't pass.  Sleep to allow it to finish
                        rsh $clt_nfs "echo \"/export/${clt_nfs}_${num_nfs} (rw)\" >> ${EXPORTS}"
                        rsh $clt_nfs "/etc/init.d/nfs restart &"
                        sleep 15
                fi
        else
                # configure the local host
                if (( ! $(grep -c '/export (rw)' ${EXPORTS}) )); then
                        # linux.  Must run nfs restart in backgroud otherwise
                        # it won't pass.  Sleep to allow it to finish
                        echo "/export/${clt_nfs}_${num_nfs} (rw)" >> ${EXPORTS}
                        /etc/init.d/nfs restart
                        sleep 15
                fi
        fi
}


setup_nfs() {
        $PRINTF "Configuring nfs";

        if [[ $TRAFFIC_TYPE != "rx" ]]; then
                mkdir -p /mnt
                chmod 777 /mnt
        fi
        if [[ $TRAFFIC_TYPE != "tx" ]]; then
                mkdir -p /export
                chmod 777 /export
        fi

        field_pos=1
	for host in $SERVER_INT; do
                clt=$(echo $CLIENT_INT |cut -d " " -f $field_pos)
		make_base_dirs $clt       #make sure /export and /mnt exist
                i=1
                while (( $i <= $SESSIONS )); do
        		if [[ $TRAFFIC_TYPE != "rx" ]]; then
				# Remote share
		                rsh $clt "mkdir -p /export/${clt}_${i}"
               			rsh $clt "chmod 777 /export/${clt}_${i}"
                		mkdir -p /mnt/${clt}_${i}
                		chmod 777 /mnt/${clt}_${i}

			        # configure nfs on the client remote 0
			        if [[ $(uname -s) == SunOS ]]; then
			                setup_nfs_Solaris $clt $i 0
			        elif [[ $(uname -s) == Linux ]]; then
			                setup_nfs_Linux $clt $i 0
			        else
			                $PRINTF "Unsupported OS Exiting\n"
			                exit 8
			        fi
        		fi
        		if [[ $TRAFFIC_TYPE != "tx" ]]; then
                		# make the reverse direction mounts 
                		mkdir -p /export/${host}_${i}
                		chmod 777 /export/${host}_${i}
                		rsh $clt "mkdir -p /mnt/${host}_${i}"
                		rsh $clt "chmod 777 /mnt/${host}_${i}"

			        # configure nfs on the server local 1 
			        if [[ $(uname -s) == SunOS ]]; then
			                setup_nfs_Solaris $host $i 1
			        elif [[ $(uname -s) == Linux ]]; then
			                setup_nfs_Linux $host $i 1
			        else
			                $PRINTF "Unsupported OS Exiting\n"
			                exit 8
			        fi
        		fi
			i=$(( $i + 1 ))
		done

		if [[ $TRAFFIC_TYPE != "rx" ]]; then
       		 	# Remote share
			if [[ $(uname -s) == SunOS ]]; then
	                        if (( $(rsh $clt "uname -r | \
					cut -d '.' -f 2") >= 10 )); then
	                                # Solaris 10 and greater
	                                rsh $clt "svcadm enable -r svc:/network/nfs/status:default"
	                                rsh $clt "svcadm enable -r svc:/network/nfs/nlockmgr:default"
	                                rsh $clt "svcadm enable -r svc:/network/nfs/server:default"
	                                rsh $clt "svcadm enable -r svc:/network/nfs/client:default"
					rsh $clt "shareall -F nfs"
	                        else
	                                # Solaris 8 and 9
	                                rsh $clt_nfs "/etc/init.d/nfs.server stop"
	                                rsh $clt_nfs "/etc/init.d/nfs.server start"
					sleep 15 	#Like linux
	                        fi
			elif [[ $(uname -s) == Linux ]]; then
                        	rsh $clt_nfs "/etc/init.d/nfs restart &"
                        	sleep 15
			else
			        $PRINTF "Unsupported OS Exiting\n"
			        exit 8
			fi
		fi
		if [[ $TRAFFIC_TYPE != "tx" ]]; then
			# Local share
			if [[ $(uname -s) == SunOS ]]; then
	                        if (( $(uname -r |cut -d '.' -f 2) >= 10 )); then
	                                # Solaris 10 and greater
	                                svcadm enable -r svc:/network/nfs/status:default
	                                svcadm enable -r svc:/network/nfs/nlockmgr:default
	                                svcadm enable -r svc:/network/nfs/server:default
	                                svcadm enable -r svc:/network/nfs/client:default
					shareall -F nfs
	                        else
	                                # Solaris 8 and 9
	                                /etc/init.d/nfs.server stop
	                                /etc/init.d/nfs.server start
					sleep 15
	                        fi
			elif [[ $(uname -s) == Linux ]]; then
                        	/etc/init.d/nfs restart
                        	sleep 15
			else
			        $PRINTF "Unsupported OS Exiting\n"
			        exit 8
			fi
		fi

		field_pos=$(( $field_pos + 1 ))
	done

        $PRINTF " ."
	sleep 2 	# Wait for nfs restart
        $PRINTF " DONE\n"
}


make_base_dirs() {
        clt_base=$1
        # only need done once per client
        if [[ $TRAFFIC_TYPE != "rx" ]]; then
                rsh $clt_base "mkdir -p /export"
                rsh $clt_base "chmod 777 /export"
        fi
        if [[ $TRAFFIC_TYPE != "tx" ]]; then
                rsh $clt_base "mkdir -p /mnt"
                rsh $clt_base "chmod 777 /mnt"
        fi
}


make_mount() {
        hst=$1
        clnt=$2
        num=$3
        if [[ $TRAFFIC_TYPE != "rx" ]]; then
                mount -o proto=${PROTO} ${clnt}:/export/${clnt}_${num} \
                         /mnt/${clnt}_${num}
                if [[ $? != 0 ]]; then
                        # this should catch if anything before failed
                        print "Could not mount ${clnt}:/export/${clnt}_${num}"
                        exit 9
                fi
                $PRINTF " ."
        fi

        if [[ $TRAFFIC_TYPE != "tx" ]]; then
                # make the reverse direction mounts
                error=$(rsh $clnt "mount -o proto=${PROTO} \
                        ${hst}:/export/${hst}_${num} /mnt/${hst}_${num} \
			> /dev/null 2>&1; echo \$?")
                if [[ $error != 0 ]]; then
                        print "Could not mount ${hst}:/export/${hst}_${num}"
                        exit 9
                fi
                $PRINTF " ."
        fi
}


setup_corrupt() {
        # configure nfs
        setup_nfs

        # push testcorrupt out to server/clients
        distribute_binary 

        $PRINTF "Configuring mount points"
      
	# Make mount points as needed
        field_pos=1
	for host in $SERVER_INT; do
                clt=$(echo $CLIENT_INT |cut -d " " -f $field_pos)
                i=1
                while (( $i <= $SESSIONS )); do
                        # need done for each session of each client
                        make_mount $host $clt $i
                        i=$(( $i + 1 ))
                done
                field_pos=$(( $field_pos + 1 ))
        done
        $PRINTF " DONE\n"
}


start_corrupt() {
        $PRINTF "Starting Corrupt";
        field_pos=1
	for host in $SERVER_INT; do
                clt=$(echo $CLIENT_INT |cut -d " " -f $field_pos)
                i=1
                while (( $i <= $SESSIONS )); do
                        if [[ $TRAFFIC_TYPE != "rx" ]]; then
                                msg="Results for ${host} --> ${clt} session# $i"
                                print "${msg}" > /tmp/Corrupt_${host}_${i}
                                /tmp/testcorrupt -t ${TIME} \
                                                 -f /mnt/${clt}_${i}/tcor \
                                        >> /tmp/Corrupt_${host}_${i} 2>&1 &
                                $PRINTF " ."
                        fi
                        if [[ $TRAFFIC_TYPE != "tx" ]]; then
                                msg="Results for ${clt} --> ${host} session# $i"
                                print "${msg}" > /tmp/Corrupt_${clt}_${i}
                                rsh $clt "/tmp/testcorrupt -t ${TIME} \
                                        -f /mnt/${host}_${i}/tcor"  \
                                        >> /tmp/Corrupt_${clt}_${i} 2>&1 &
                                $PRINTF " ."
                        fi
                        i=$(( $i + 1 ))
                done
                field_pos=$(( $field_pos + 1 ))
        done
        $PRINTF " DONE\n"

        $PRINTF "Corrupt Started.  Running for ${TIME} seconds\n";
}


kill_corrupt_processes() {
        # kill the client sessions
	for clt in $CLIENT_INT; do
                rsh ${clt} "pkill testcorrupt"
        done

        # kill the server sessions
        pkill testcorrupt

        # mark the tmp files as killed
        for file in /tmp/Corrupt_*; do
                print "KILLED:run on error is no" >> ${file}
        done
}


get_epoch() {
        seconds=0
        if [[ $(uname -s) == SunOS ]]; then
                seconds=$(/usr/bin/truss /usr/bin/date 2>&1 \
                        | /usr/bin/awk '/^time/ {print $NF}')
        elif [[ $(uname -s) == Linux ]]; then
                seconds=$(date -u +%s)
        fi

        print "${seconds}"
}


monitor_corrupt() {
        # time is based on system time i.e. epoch so total time is accurate
        # even if the system goes down in a suspend/resume operation
        start_time=$(get_epoch)
        current_time=$(get_epoch)
        seconds_waited=$(( ${current_time} - ${start_time} ))
        while (( ${seconds_waited} < ${TIME} )); do
                if (( (${TIME} - ${seconds_waited} ) <  ${WAITINT} )); then
                        SLEEPTIME=$(( ${TIME} - ${seconds_waited} ))
                else
                        SLEEPTIME=${WAITINT}
                fi
                sleep ${SLEEPTIME}
                current_time=$(get_epoch)
                seconds_waited=$(( ${current_time} - ${start_time} ))

                count=0
                for status_file in /tmp/Corrupt_*; do
                        count=$(( ${count} + $(grep -c FAIL ${status_file}) ))
                done

                if (( ${count} > 0 )); then
                        if [[ "${RUN_ON_ERROR}" == "no" ]]; then
                                kill_corrupt_processes
                                break
                        fi
                fi
        done
}


wait_for_threads_to_finish() {
        $PRINTF "Waiting for processes to finish";

        # Calculate the number of sessions
        (( num_clients = ( $(echo "$CLIENT_INT" | awk '{print --NF}') + 1 ) ))
        if [[ $TRAFFIC_TYPE == "bi" ]]; then
                (( num_sessions = ${num_clients} * ${SESSIONS} * 2 ))
        else
                (( num_sessions = ${num_clients} * ${SESSIONS} ))
        fi

        start_time=$(get_epoch)
        current_time=$(get_epoch)
        seconds_waited=$(( ${current_time} - ${start_time} ))
        while (( ${seconds_waited} < ${MAXWAIT} )); do
                count=0
                field_pos=1
	        for host in $SERVER_INT; do
                        clt=$(echo $CLIENT_INT |cut -d " " -f $field_pos)
                        i=1
                        while (( $i <= $SESSIONS )); do
                                if [[ $TRAFFIC_TYPE != "rx" ]]; then
                                        (( tmp=$(egrep -c "(PASS|FAIL|KILLED)" \
                                                /tmp/Corrupt_${host}_${i}) ))
                                        if (( $tmp > 1 )); then
                                                (( tmp = 1 ))
                                        fi
                                        count=$(( ${count} + ${tmp} ))
                                fi
                                if [[ $TRAFFIC_TYPE != "tx" ]]; then
                                        (( tmp=$(egrep -c "(PASS|FAIL|KILLED)" \
                                                /tmp/Corrupt_${clt}_${i}) ))
                                        if (( $tmp > 1 )); then
                                                (( tmp = 1 ))
                                        fi
                                        count=$(( ${count} + ${tmp} ))
                                fi
                                i=$(( $i + 1 ))
                        done
                        field_pos=$(( $field_pos + 1 ))
                done

                #all the sessions have a pass, fail, or killed
                if (( ${count} == ${num_sessions} )); then
                        seconds_waited=${MAXWAIT}
                else
                        sleep ${WAITINT}
                        $PRINTF " ."
                        current_time=$(get_epoch)
                        seconds_waited=$(( ${current_time} - ${start_time} ))
                fi
        done
        $PRINTF " DONE"
}


get_results() {
        # write a date string of when the test happened
        datestr="Corrupt Results for $(hostname) Completed"
        datestr="${datestr} $(date '+%Y-%m-%d_%H:%M:%S')"
        $PRINTF "\n${datestr}\n\n" | tee -a ${LOGFILE}

        # include the results from testcorrupt
        # get number of passes and fails
        passed_ses=0
        num_fails=0
        for file in /tmp/Corrupt_*; do
                cat "${file}" | tee -a ${LOGFILE}
                $PRINTF "\n" | tee -a ${LOGFILE}

                # increment the PASS count if a pass found
                if (( $(grep -c PASS ${file}) )); then
                        passed_ses=$(( $passed_ses + 1 ))
                fi

                # increment the Fail count if a Fail found
                (( tmp = $(grep -c FAIL ${file}) ))
                if (( ${tmp} >= 2 )); then
                        # number of fails is -1 since the overall status
                        # line prints fail unless it was a file write 
                        # issue
                        tmp=$(( ${tmp} - 1 ))
                fi
                num_fails=$(( ${num_fails} + ${tmp} ))
        done

        # document the setup
        $PRINTF "Setup Summary\n" | tee -a ${LOGFILE}
        $PRINTF "======================================\n" | tee -a ${LOGFILE}
        $PRINTF "PRODUCT      : ${PRODUCT}\n" | tee -a ${LOGFILE}
        $PRINTF "CLIENT_INT   : ${CLIENT_INT}\n" | tee -a ${LOGFILE}
        $PRINTF "SERVER_INT   : ${SERVER_INT}\n" | tee -a ${LOGFILE}
        $PRINTF "SESSIONS     : ${SESSIONS}\n" | tee -a ${LOGFILE}
        $PRINTF "TIME         : ${TIME} sec\n" | tee -a ${LOGFILE}
        $PRINTF "TRAFFIC_TYPE : ${TRAFFIC_TYPE}\n" | tee -a ${LOGFILE}
        $PRINTF "PROTO        : ${PROTO}\n" | tee -a ${LOGFILE}
        $PRINTF "RUN_ON_ERROR : ${RUN_ON_ERROR}\n" | tee -a ${LOGFILE}
        $PRINTF "\n\n" | tee -a ${LOGFILE}

        $PRINTF "Corrupt Status\n" | tee -a ${LOGFILE}
        $PRINTF "======================================\n" | tee -a ${LOGFILE}

        # present the pass/fail status
        (( num_clients = ( $(echo "$CLIENT_INT" | awk '{print --NF}') + 1 ) ))
        if [[ $TRAFFIC_TYPE == "bi" ]]; then
                (( num_sessions = ${num_clients} * ${SESSIONS} * 2 ))
        else
                (( num_sessions = ${num_clients} * ${SESSIONS} ))
        fi

        if (( $num_fails != 0 )); then
                $PRINTF "FAILED: Found ${num_fails} Failures in logfile\n" \
                       | tee -a ${LOGFILE}
                STATUS='F'
                return
        fi

        # if they are not failed and not passed then they did not finish
        if (( $passed_ses != ${num_sessions} )); then
                msg="${passed_ses} of ${num_sessions} sessions finished"
                print "FAILED: ${msg}" | tee -a ${LOGFILE}
                STATUS='F'
                return
        fi
        
        # other wise we Pass
        $PRINTF "PASSED: Found No Corruption\n" | tee -a ${LOGFILE}
        STATUS='P'
}


mail_results() {
	if [[ ${MAILTO} == "no" ]]; then
		# sendmail is useless in nicdrv test, it has unified log.
		return 0
	fi
        subject="${PRODUCT}:Corrupt results on $(hostname)"
        if [[ $(uname -s) == SunOS ]]; then
                cat ${LOGFILE} | mailx -s "${subject}" "${MAILTO}"
        elif [[ $(uname -s) == Linux ]]; then
                cat ${LOGFILE} | mail -s "${subject}" "${MAILTO}"
        fi 
}


cleanup_nfs_Solaris() {
        clt_nfs=$1
	num_nfs=$2
	local=$3
        if [ $local -ne 1 ]; then
                # cleanup nfs on a remote host 
		ret=$(rsh ${clt_nfs} "grep -c \"share -F nfs /export/${clt_nfs}_${num_nfs}\" \
			${DFSTAB}")
                if (( $ret )); then
                        rsh $clt_nfs "grep -v \"share -F nfs /export/${clt_nfs}_${num_nfs}\" \
				${DFSTAB} > /tmp/dfs"
                        rsh $clt_nfs "mv -f /tmp/dfs ${DFSTAB}"
                fi
        else
                # cleanup nfs on the local host 
                if (( $(grep -c "share -F nfs /export/${clt_nfs}_${num_nfs}" "${DFSTAB}") )); then
                        grep -v "share -F nfs /export/${clt_nfs}_${num_nfs}" ${DFSTAB} > /tmp/dfs
                        mv -f /tmp/dfs "${DFSTAB}"
                fi
        fi
}


cleanup_nfs_Linux() {
        clt_nfs=$1
        num_nfs=$2
        local=$3
        if [  $local -ne 1 ]; then
                # cleanup nfs on a remote host 
                if (( $(rsh ${clt_nfs} "grep -c \"/export/${clt_nfs}_${num_nfs} (rw)\" ${EXPORTS}") )); then
                        # linux.  Must run nfs restart in backgroud otherwise
                        # it won't pass.  Sleep to allow it to finish
                        rsh ${clt_nfs} "grep -v \"/export/${clt_nfs}_${num_nfs} (rw)\" ${EXPORTS} > \
                                    /tmp/exports "
                        rsh ${clt_nfs} "mv -f /tmp/exports ${EXPORTS}"
                        rsh ${clt_nfs} "/etc/init.d/nfs restart &"
                        sleep 15
                fi
        else
                # cleanup nfs on the local host
                if (( $(grep -c '/export/${clt_nfs}_${num_nfs} (rw)' ${EXPORTS}) )); then
                        grep -v '/export/${clt_nfs}_${num_nfs} (rw)' ${EXPORTS} > /tmp/exports
                        mv -f /tmp/exports ${EXPORTS}
                        /etc/init.d/nfs restart
                        sleep 15
                fi
        fi
}

# $1: hostname, $2: num , $3: local label
cleanup_nfs() {
        #$PRINTF "Deconfiguring nfs";

        # unconfigure nfs on the server
        if [[ $(uname -s) == SunOS ]]; then
                cleanup_nfs_Solaris $1 $2 $3
        elif [[ $(uname -s) == Linux ]]; then
                cleanup_nfs_Linux $1 $2 $3
        else
                $PRINTF "Unsupported OS Exiting\n"
                exit 8
        fi
        $PRINTF " ."
        #$PRINTF " DONE\n"
}

# $1: hostname, $2: local 1, remote 0
restart_nfs() {
	clt_res=$1

	$PRINTF "Restarting nfs";

	# unconfigure nfs on the server
	if [[ $(uname -s) == SunOS ]]; then
		if [ $2 -ne 1 ]; then
			# service management changed in solaris 10
			if (( $(rsh $clt_res "uname -r | \
	    			cut -d '.' -f 2") >= 10 )); then
				rsh $clt_res "shareall -F nfs"
			else
               	        	rsh $clt_res "/etc/init.d/nfs.server stop"
				rsh $clt_res "/etc/init.d/nfs.server start"
				sleep 15
	    		fi
		else	
			# service management changed in solaris 10
			if (( $(uname -r |cut -d '.' -f 2) >= 10 )); then
				shareall -F nfs
			else
				/etc/init.d/nfs.server stop
				/etc/init.d/nfs.server start
				sleep 15
			fi
		fi

	elif [[ $(uname -s) == Linux ]]; then
		if [ $2 -ne 1 ]; then
                        rsh ${clt_nfs} "/etc/init.d/nfs restart &"
                        sleep 15
		else	
                        /etc/init.d/nfs restart
                        sleep 15
		fi
	else
	        $PRINTF "Unsupported OS Exiting\n"
	    	exit 8
	fi
	$PRINTF " ."
	$PRINTF " DONE\n"

}

saveResultToDatabase() {
        # ${LOGFILE} is the full path the the results file
        # ${RESULT_TITLE} is a string
        # ${STATUS} must be P or F
        # ${TEST_MATRIX_ID} is the passed database locator. a unsigned int

        # For NSN test database only
        if [ "X${TEST_MATRIX_ID}" != "X" ]; then
                if [[ -f /suites/utils/TestMatrix/SaveTestResults.ksh ]]; then
                        RESULT_TITLE="${PRODUCT}:Corrupt results on $(hostname)"
                        /suites/utils/TestMatrix/SaveTestResults.ksh \
                                                        -f ${LOGFILE} \
                                                        -t ${RESULT_TITLE}\
                                                        -p ${STATUS} \
                                                        -m ${TEST_MATRIX_ID}
                        if [[ $? != 0 ]]; then
                                echo "Upload of result failed"
                                echo "Test results not logged in database"
                        fi
                else
                        $PRINTF "/suites/utils/TestMatrix/SaveTestResults.ksh"
                        print " does not exist"
                        print "Test results not logged in database"
                fi
        fi
}


cleanup_corrupt() {
        $PRINTF "Removing mount points";

        # remove the mount points and directories
        field_pos=1
	for host in $SERVER_INT; do
                clt=$(echo $CLIENT_INT |cut -d " " -f $field_pos)

                # remove the test binary from client
		rsh ${clt} "rm -rf /tmp/testcorrupt"
                i=1
                while (( $i <= $SESSIONS )); do
                        if [[ $TRAFFIC_TYPE != "rx" ]]; then
                                umount /mnt/${clt}_${i}

				# restore nfs settings on client, 0 remote
				cleanup_nfs $clt $i 0

                                rm -rf /mnt/${clt}_${i}
                                rsh $clt "rm -rf /export/${clt}_${i}"
                                $PRINTF " ."
                        fi
        
                        if [[ $TRAFFIC_TYPE != "tx" ]]; then
                                # remove the reverse direction mounts
                                rsh $clt "umount /mnt/${host}_${i}"

				# restore nfs settings on local
				cleanup_nfs $host $i 1

                                rsh $clt "rm -rf /mnt/${host}_${i}"
                                rm -rf /export/${host}_${i}
                                $PRINTF " ."
                        fi
                        i=$(( $i + 1 ))
                done
		# restart nfs on client
		restart_nfs $clt 0  
                field_pos=$(( $field_pos + 1 ))
        done
	# restart local nfs
	restart_nfs $host 1 
        $PRINTF " DONE\n"

        # remove the test binary from server
        rm -f /tmp/testcorrupt

        # remove the tmp log files
        rm -f /tmp/Corrupt_*

}


################################################################################
#	MAIN
################################################################################
trap "pkill testcorrupt; exit 1" 1 2 3 9 15

set_defaults
load_rc_file
process_commandline $*
verify_options
clean_after_crash
check_disk_space
setup_corrupt
start_corrupt
monitor_corrupt
wait_for_threads_to_finish
get_results
mail_results
saveResultToDatabase
cleanup_corrupt

if [ ${STATUS} = 'P' ]; then
        exit 0
else
        exit 1
fi
