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
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)mcast.auto.ksh	1.2	08/04/22 SMI"
#

usage()
{
	echo ""
	echo "Usage: `basename $0` -c client_name" 
	echo "		-cg client_gateway address for multicast route"
	echo "		-ci  client_interface_drv such as hme0, ce0 etc."
	echo "		-cp  client_port"
	echo "		-s   server_name"
	echo "		-sg  server_gateway address for multicast route, \
		like xxx.xxx.xxx.xxx"
	echo "		-si  server_interface_drv such as hme0, ce0 etc."
	echo "		-sp  server_port"
#	echo "		-n   number_of_multicast_addresses"
	echo "		-m   multicast_base_address"
	echo "		-r   send_rate"
	echo "		-t   minutes_for_sending"
	echo "		-g   group_num for testing multiple multicast groups"
	echo "		-f   run after loading config file .mcastrc"
	echo "          -stress  multicast stress test"
	echo "		--help"
	echo "  Example:"
	echo "		./mcast.auto --help"
	echo "		./mcast.auto -c uncles -cg 11.0.1.214 -ci chxge0 \
		-s truths -sg 11.0.1.213 -si chxge0 -r 1 -t 5 -m 225.0.0.1 -g 1"
	echo "		./mcast.auto -f"
	echo "  Source file: .mcastrc"
}

set_defaults() {
		
	PROG=`basename $0`; 
	TESTNAME=`basename $0 .auto`
	HOSTNAME=`uname -n`
	CURDIR=`pwd`
	SOURCEFILE="$CURDIR/.${TESTNAME}rc"
	LOGDIR="${STF_RESULTS}/tmp/${TESTNAME}"
	LOGFILE_C="${LOGDIR}/${TESTNAME}".log.client.`date '+%Y-%m-%d_%H:%M:%S'`
	LOGFILE_S="${LOGDIR}/${TESTNAME}".log.server.`date '+%Y-%m-%d_%H:%M:%S'`

	if [ ! -e $LOGDIR ]; then
		mkdir -p "$LOGDIR"
	fi


	# gateway name for local machine under test,
	# for multicast route such as xxx.xxx.xxx.xxx or hostname
	
	MCAST_CLIENT_GATEWAY="client_gateway_ip"
	MCAST_CLIENT_NAME="client_name"

	#interface under test such as hme0, ce0 etc.	
	MCAST_CLIENT_INT="drv0"

	#number of multicast addresses to be tested, default to 1.
	MCAST_CLIENT_NUM="1"

	#multicast base address to be used for testing, default to 225.0.0.1.
	MCAST_CLIENT_MIP="225.0.0.1"

	#port number, default to 5500.
	MCAST_CLIENT_PORT="5500"

	MCAST_SERVER_GATEWAY="server_gateway_ip"
	MCAST_SERVER_NAME="server_name"
	
	#interface name such as hme0, ce0 etc.
	MCAST_SERVER_INT="drv0"

	#number of multicast addresses to be tested, default to 1.
	MCAST_SERVER_NUM="1"

	#multicast base address to be used for testing, default to 225.0.0.1.
	MCAST_SERVER_MIP="225.0.0.1"

	#port number, default to 5500.
	MCAST_SERVER_PORT="5500"

	#send rate in seconds, default to 5
	MCAST_SERVER_SENDRATE="5"

	#minutes for sender to keep sending(timeout), default to 60
	MCAST_SERVER_TIMEOUT="60"

	#the number of multiple multicast groups (default 1)
	MULTIPLE_GROUP_NUM="1"

        #do stress test (default no 0)
        DO_STRESS="0"
}

#
# load .mcastrc (config file)
#
load_rc_file() {
	if [ -f $SOURCEFILE ]
	then
		. ${SOURCEFILE}
	fi
}

#
# command line
#
process_commandline() { 
	if [ $# -eq 0 ]; then
		usage
		exit 0
	fi

	for i in $*; do
		case $1 in
		-cg) MCAST_CLIENT_GATEWAY=$2
			shift 2
              	;;
		-c)  MCAST_CLIENT_NAME=$2
              	shift 2
              	;;
		-ci)  MCAST_CLIENT_INT=$2
              	shift 2
              	;;
		-n)  MCAST_SERVER_NUM=$2
              	MCAST_CLIENT_NUM=$MCAST_SERVER_NUM
              	shift 2
              	;;
		-m)  MCAST_SERVER_MIP=$2
			MCAST_CLIENT_MIP=$MCAST_SERVER_MIP
              	shift 2
              	;;
		-cp) MCAST_CLIENT_PORT=$2
              	shift 2
              	;;
		-sg) MCAST_SERVER_GATEWAY=$2
              	shift 2
              	;;
		-s)  MCAST_SERVER_NAME=$2
              	shift 2
              	;;
		-si) MCAST_SERVER_INT=$2
              	shift 2
              	;;
		-sp) MCAST_SERVER_PORT=$2
              	shift 2
              	;;
		-r)  MCAST_SERVER_SENDRATE=$2
              	shift 2
              	;;
		-t)  MCAST_SERVER_TIMEOUT=$2
              	shift 2
              	;;
		-g)  MULTIPLE_GROUP_NUM=$2
              	shift 2
			;;
                -stress)  DO_STRESS=$2
                shift 2
                        ;;
		--help)
			usage
			exit 0
			;;
		-f)
			echo "read config file"
			return 0
			;;
		-*)  
              	echo "FAILED : Invalid option"
			usage
              	exit 1
              	;;
		esac
	done
}

#
# set up the test environment
#

setup_env() {
	server_os=`uname -s`
	server_hw=`uname -p`
	server_ver=`uname -r`
	client_os=`rsh ${MCAST_CLIENT_NAME} uname -s`
	client_hw=`rsh ${MCAST_CLIENT_NAME} uname -p`
	client_ver=`rsh ${MCAST_CLIENT_NAME} uname -r`
	rmt_dir=`rsh ${MCAST_CLIENT_NAME} isainfo -n`
	rcp ${STF_SUITE}/tools/multicast/$rmt_dir/mcast_* \
		${MCAST_CLIENT_NAME}:/tmp
}

#
#Verify the interface under test is able to receive IP multicast traffic
#
test_single_recv() {

	echo "*****Test receiving ip multicast packets*****" | tee -a $LOGFILE_S

	dst_c=`netstat -nr | awk '{print $1}' | grep -c $MCAST_SERVER_MIP`
	if [ $dst_c -eq 0 ]; then
		route add $MCAST_SERVER_MIP $MCAST_SERVER_GATEWAY 2>&1 | tee -a $LOGFILE_S
		if [ $? -ne 0 ]; then
			echo "!FAIL : add route fail"
			return 0
		fi
	fi

	dst_c=`rsh -n ${MCAST_CLIENT_NAME} "netstat -nr" | \
		awk '{print $1}' | grep -c $MCAST_CLIENT_MIP`
	if [ $dst_c -eq 0 ]; then
		rsh $MCAST_CLIENT_NAME "route add $MCAST_CLIENT_MIP \
			$MCAST_CLIENT_GATEWAY 2>&1 | tee -a /tmp/client.log"
	fi

	rsh -n ${MCAST_CLIENT_NAME} "/tmp/mcast_S \
		-i ${MCAST_CLIENT_INT} -m ${MCAST_CLIENT_MIP} \
		-n ${MCAST_CLIENT_NUM} -p ${MCAST_CLIENT_PORT} \
		-s ${MCAST_SERVER_SENDRATE} -t ${MCAST_SERVER_TIMEOUT} \
		>> /tmp/client.log &" &

	${STF_SUITE}/tools/multicast/`isainfo -n`/mcast_R \
		-i ${MCAST_SERVER_INT} -m ${MCAST_SERVER_MIP} \
		-n ${MCAST_SERVER_NUM} -p ${MCAST_SERVER_PORT} | tee -a $LOGFILE_S

	rsh ${MCAST_CLIENT_NAME} pkill ${TESTNAME}
}


test_single_send() {
	echo "*****Test sending ip multicast packets*****" | tee -a $LOGFILE_S

	rsh -n ${MCAST_CLIENT_NAME} "/tmp/mcast_R \
		-i ${MCAST_CLIENT_INT} -m ${MCAST_CLIENT_MIP} \
		-n ${MCAST_CLIENT_NUM} -p ${MCAST_CLIENT_PORT} \
		>> /tmp/client.log &" &

	${STF_SUITE}/tools/multicast/`isainfo -n`/mcast_S \
		-i ${MCAST_SERVER_INT} -m ${MCAST_SERVER_MIP} \
		-n ${MCAST_SERVER_NUM} -p ${MCAST_SERVER_PORT} \
		-s ${MCAST_SERVER_SENDRATE} -t ${MCAST_SERVER_TIMEOUT} | tee -a $LOGFILE_S

	rsh ${MCAST_CLIENT_NAME} pkill ${TESTNAME}
}

test_multi_recv() {
 
	temp_num=$MCAST_CLIENT_NUM
	MCAST_CLIENT_NUM=$MULTIPLE_GROUP_NUM
	MCAST_SERVER_NUM=$MCAST_CLIENT_NUM

	test_single_recv

	MCAST_CLIENT_NUM=$temp_num
	MCAST_SERVER_NUM=$MCAST_CLIENT_NUM

}


test_multi_send() {
	temp_num=$MCAST_CLIENT_NUM
	MCAST_CLIENT_NUM=$MULTIPLE_GROUP_NUM
	MCAST_SERVER_NUM=$MCAST_CLIENT_NUM

	test_single_send

	MCAST_CLIENT_NUM=$temp_num
	MCAST_SERVER_NUM=$MCAST_CLIENT_NUM

}

test_fragment() { :; }

#
#function: Multicast Stress Test 
#
test_stress() { 
	if [ $DO_STRESS -eq 1 ]; then
       		echo "*****multicast stress test receiving*****" | tee -a $LOGFILE_S
        	rsh -n ${MCAST_CLIENT_NAME} "/tmp/mcast_S_stress \
			-i ${MCAST_CLIENT_INT} -m ${MCAST_CLIENT_MIP} \
			-p ${MCAST_CLIENT_PORT} -t ${MCAST_SERVER_TIMEOUT} \
			>> /tmp/client.log &" &

        	${STF_SUITE}/tools/multicast/`isainfo -n`/mcast_R_stress \
			-i ${MCAST_SERVER_INT} -m ${MCAST_SERVER_MIP} \
			-p ${MCAST_SERVER_PORT} | tee -a $LOGFILE_S

        	rsh ${MCAST_CLIENT_NAME} pkill ${TESTNAME}

        	echo "*****multicast stress test sending*****" | tee -a $LOGFILE_S

        	rsh -n ${MCAST_CLIENT_NAME} "/tmp/mcast_R_stress \
			-i ${MCAST_CLIENT_INT} -m ${MCAST_CLIENT_MIP} \
			-p ${MCAST_CLIENT_PORT} >> /tmp/client.log &" &

        	${STF_SUITE}/tools/multicast/`isainfo -n`/mcast_S_stress \
			-i ${MCAST_SERVER_INT} -m ${MCAST_SERVER_MIP} \
			-p ${MCAST_SERVER_PORT} -t ${MCAST_SERVER_TIMEOUT} | tee -a $LOGFILE_S

        	rsh ${MCAST_CLIENT_NAME} pkill ${TESTNAME}

	fi
}


#
#save the log and clear the environment
#
clear_env() {
	echo "clear the environment..."

	rsh $MCAST_CLIENT_NAME "route delete \
		$MCAST_CLIENT_MIP $MCAST_CLIENT_GATEWAY 2>&1 | \
		tee -a /tmp/client.log"
	route delete $MCAST_SERVER_MIP $MCAST_SERVER_GATEWAY 2>&1 | tee -a $LOGFILE_S

	rcp ${MCAST_CLIENT_NAME}:/tmp/client.log $LOGFILE_C
	rsh ${MCAST_CLIENT_NAME} rm -f /tmp/client.log

	rsh ${MCAST_CLIENT_NAME} pkill ${TESTNAME}
	rsh ${MCAST_CLIENT_NAME} rm /tmp/mcast_*

	pkill ${TESTNAME}_

}

#
# Check multi groups from the log 
#
check_multi_result() {
	echo "Check result..."
	addr_prefix=`echo ${MCAST_CLIENT_MIP} | sed 's/[0-9]*$//'`
	addr_suffix=`echo ${MCAST_CLIENT_MIP} | cut -d. -f4`
	temp=0
	while [ $temp -lt $MULTIPLE_GROUP_NUM ]; do
		addr_s=$(( $addr_suffix + $temp ))
		if [ $addr_s -gt 254 ]; then
			return 0
		fi
		addr_t="${addr_prefix}${addr_s}"
		grep "$addr_t" $LOGFILE_S > /dev/null
		if [ $? -ne 0 ]; then
			echo "Recv multiple groups FAIL!"
			return 1
		fi
		temp=$(($temp + 1))
	done
	return 0
}

########################################
#	MAIN
########################################
ret=0
set_defaults
load_rc_file
process_commandline $*
setup_env

#
#capture Ctrl-C or kill signals
#
trap "clear_env; exit" 1 2 3 9 15

#
#Test single multicast group. 
#First test the receiving. Then test sending.
#
test_single_recv
test_single_send

#
#Test multiple multicast groups
#
if [ $MULTIPLE_GROUP_NUM -gt 1 ]; then
	echo "*****test multiple multicast groups*****"
	test_multi_recv
	check_multi_result
	ret=$?
		 
# We needn't test sending multiple multicast groups packets,
# only test receiving.  
#	test_multi_send
fi

#test_fragment

#
# Multicast Stress Test
#
#test_stress

clear_env

echo ""
echo "END!"

exit $ret
