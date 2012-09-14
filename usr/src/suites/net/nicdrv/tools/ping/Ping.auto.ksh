#!/usr/bin/ksh
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
# ident	"@(#)Ping.auto.ksh	1.5	09/06/24 SMI"
#

#
# Usage: Ping.auto -i <local_interface> -r <remote_interface>
#			-c <remote_address> -h <local_address>
#
usage()
{
	echo "\nUsage: `basename $0` --help | \
		-i <interface> -r <remote_interface> \
		-c <remote_address> -h <local_address>"
	echo "  Options:"
	echo "		--help:	Help information"
	echo "		-i:	Local test interface, like e1000g0, bge1 etc"
	echo "		-r:	Remote test interface, like e1000g0"
	echo "		-c:	Remote host IP address"
	echo "		-h:	Local host IP address"
	echo "		-t:	ping_zero/ping_all_size"
	echo "		-s:	max payload size"
	echo "  Example:"
	echo "		./Ping.auto --help"
	echo "		./Ping.auto -i e1000g0 -r bge0 -c 11.0.1.2 -h 11.0.1.1"
} 

#
# This test case is to verify:
# 1. Test interface could transmit and receive ICMP packets of different sizes
# 2. Padding of small packets is correct with "00"
#
ping_zero()
{
	echo "$TEST_NAME: ping_zero: begins..."
	#
	# Start snoop on remote host to capture a ICMP packet,
	# which has src IP of local host
	#
	ping -s $CLIENT_IP 0 > /dev/null &
	rsh -l root ${CLIENT_IP} "snoop -c 1 -o ${TMP_LOG} \
		-d ${REMOTE_INT} src ${LOCAL_IP} icmp[0:2]=0x800"

	if [ $? -ne 0 ]; then
        	echo "$TEST_NAME: ping_zero: rsh to client and snoop failed"
		echo "TEST $TEST_NAME ENDS"
        	exit 1;
	fi

	pkill ping
	#
	# Below to deal with IP without option, does not deal with 
	# IP headers with options. Read from packet offset 42
	#
	rsh -l root ${CLIENT_IP} "snoop -i ${TMP_LOG} -x42"
	rsh -l root ${CLIENT_IP} "rm ${TMP_LOG}"
	echo "$TEST_NAME: ping_zero: ends"
}

#
# It will ping remote host with ICMP payload ranging from
# 0 - MAX_PAYLOAD
# Note: 65507 payload + 8's ICMP Echo Request header + 20's IP header = 65535
#       Max IP packet allowed is : 65535 bytes
# 65508 (MAX_PAYLOAD +1) payload as a negative test case
#
ping_all_size()
{
	echo "$TEST_NAME: ping_all_size: begins..."
	icmp_pay_load=0
	flag_10=$(expr $MAX_PAYLOAD / 10)
	flag_20=$(expr $MAX_PAYLOAD / 5)
	flag_30=$(expr $MAX_PAYLOAD / 10 \* 3)
	flag_40=$(expr $MAX_PAYLOAD / 5 \* 2) 
	flag_50=$(expr $MAX_PAYLOAD / 2) 
	flag_60=$(expr $MAX_PAYLOAD / 5 \* 3) 
	flag_70=$(expr $MAX_PAYLOAD / 10 \* 7) 
	flag_80=$(expr $MAX_PAYLOAD / 5 \* 4) 
	flag_90=$(expr $MAX_PAYLOAD / 10 \* 9) 
	FAIL_FLAG=0
	while [ $icmp_pay_load -le $MAX_PAYLOAD ]; do
		case "$icmp_pay_load" in
	
		$flag_10 )
			echo "ping_all_size: 10% Done ...(time)`date | awk '{print $4}'` "
		;;

		$flag_20 )
			echo "ping_all_size: 20% Done ...(time)`date | awk '{print $4}'` "
		;;
		$flag_30 )
			echo "ping_all_size: 30% Done ...(time)`date | awk '{print $4}'` "
		;;

		$flag_40 )
			echo "ping_all_size: 40% Done ...(time)`date | awk '{print $4}'` "
		;;	

		$flag_50 )
			echo "ping_all_size: 50% Done ...(time)`date | awk '{print $4}'` "
		;;	
		$flag_60 )
			echo "ping_all_size: 60% Done ...(time)`date | awk '{print $4}'` "
		;;
		$flag_70 )
			echo "ping_all_size: 70% Done ...(time)`date | awk '{print $4}'` "
		;;

		$flag_80 )
			echo "ping_all_size: 80% Done ...(time)`date | awk '{print $4}'` "
		;;
		$flag_90 )
			echo "ping_all_size: 90% Done ...(time)`date | awk '{print $4}'` "
		;;

		$MAX_PAYLOAD )
			echo "ping_all_size: 100% Done ...(time)`date | awk '{print $4}'` "
		;;
		esac

		#
		# Only when ICMP payload > 8 bytes, it could
		# print RTT. It does not matter
		# 
		ping -s $CLIENT_IP $icmp_pay_load 1 > /dev/null
		if [ $? -ne 0 ]; then
			echo "ping: payload $icmp_pay_load failed"
			FAIL_FLAG=1
		fi
		icmp_pay_load=`expr $icmp_pay_load + 1`
	done

	echo "$TEST_NAME: ping_all_size: 100% done"

	# 65508 boundary case
	for boundary in 65507 65508; do
		ping -s $CLIENT_IP $boundary 1 > /dev/null
		ret=$?
		case "$boundary" in
		65507 )
			echo "$TEST_NAME: boundary case: ping with payload 65507"
			if [ $ret -ne 0 ]; then
				echo "ping: payload 65507 test failed"
				FAIL_FLAG=1
			fi
			;;
		65508 )
			echo "$TEST_NAME: negative case: ping with payload 65508"
			if [ $ret -eq 0 ]; then
				echo "ping: payload 65508 test failed"
				FAIL_FLAG=1
			fi
			;;
		esac
	done

	if [ $FAIL_FLAG -ne 0 ]; then
       		return 1
	fi

        return 0
}

setup()
{
	for i in $*; do
		case $1 in
			-i) LOCAL_INT=$2
			    export LOCAL_INT
			    shift 2
			    ;;
			-r) REMOTE_INT=$2
	                    export REMOTE_INT
			    shift 2
			    ;;
			-c) CLIENT_IP=$2
			    export CLIENT_IP
			    shift 2
			    ;;
			-h) LOCAL_IP=$2
			    export LOCAL_IP
			    shift 2
			    ;;
		esac
	done
}

#
# Check to see if running as root
#
TEST_NAME=`basename $0`
TMP_LOG="/tmp/${TEST_NAME}.tmp.`date '+%y.%m.%d.%H.%M.%S'`.log"

if [ $# -eq 0 ]; then
	usage
	exit 0
fi

for i in $*; do
    case $1 in
       -i) LOCAL_INT=$2
           export LOCAL_INT
           shift 2
           ;;
       -r) REMOTE_INT=$2
           export REMOTE_INT
           shift 2
           ;;
       -c) CLIENT_IP=$2
           export CLIENT_IP
           shift 2
           ;;
       -h) LOCAL_IP=$2
           export LOCAL_IP
           shift 2
           ;;
        -l) LOG_DIR=$2
           export LOG_DIR
           shift 2
           ;;
 	-t) TEST_NUM=$2
           export TEST_NUM
           shift 2
           ;;
 	-s) TEST_SIZE=$2
           export TEST_SIZE
           shift 2
           ;;

	--help) usage
		exit 0
		;;
   esac
done

echo "TEST $TEST_NAME BEGINS"

if [[ -z "$TEST_SIZE" ]]; then
	MAX_PAYLOAD=65507
else
	MAX_PAYLOAD=$TEST_SIZE
fi

if [[ -z "$TEST_NUM" ]]; then
	ping_zero 
	ping_all_size
elif [[ $TEST_NUM == "ping_zero" ]]; then
	ping_zero
elif [[ $TEST_NUM == "ping_all_size" ]]; then
	ping_all_size
fi


if [ $? -ne 0 ]; then
	exit 1
fi

exit 0
echo "TEST $TEST_NAME ENDS"
