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
# ident	"@(#)Statistic.auto.ksh	1.5	09/03/04 SMI"
#

. ${STF_TOOLS}/include/stf_common.kshlib
. ${STF_SUITE}/include/common.kshlib

usage()
{
	echo "\nUsage: `basename $0` --help | -i <interfaces>"
	echo "  Options:"
	echo "		--help: 	Help information"
	echo "		-i: 		Test interface, like e1000g, bge etc"
	echo "		-n: 		Interface's instance number"
	echo "		-c:		Remote host IP"
	echo "  Example:"
	echo "		./Statistic.auto --help"
	echo "		./Statistic.auto -i e1000g -n 0"
	echo "		./Statistic.auto -i bge -n 0 -c 11.0.1.1"
}
#
# Usage:
#        Statistic.auto -i <interface>
# Function:
#	1. Check output of "dladm show-link -s"
#	2. Check output of "netstat -I <interface> 1", count 500 times
#
TESTNAME=`basename $0`
TIMEOUT=`get_parameter BG_TRAFFIC_TIMEOUT`
COUNT=`get_parameter NETSTAT_COUNT`

#
# Check if OS support Nemo
#
nemo_stat=0
if [ ! -f /usr/sbin/dladm ]; then
	echo "$TESTNAME: WARNING:"
        echo "\t\tCurrent OS not support dladm, some test skipped!"
else
	nemo_stat=1
fi

if [ $# -eq 0 ]; then
	usage
	exit 0
fi

for i in $*; do
	case $1 in
		-i)
			LOCAL_INTERFACE=$2
			export LOCAL_INTERFACE
			shift 2
			;;
		-c)
			REMOTE_HOST=$2
			export REMOTE_HOST
			shift 2
			;;
		-n)
			INTERFACE_NUM=$2
			export INTERFACE_NUM
			shift 2
			;;
		--help)
			usage
			exit 0
			;;
	esac
done

echo "TEST $TESTNAME BEGINS"

trap "pkill bg_traffic; exit 1" 1 2 3 9 15
#
# Start some network traffic in background for 900 seconds
#
if [ ! -z $REMOTE_HOST ]; then
	${STF_SUITE}/${STF_EXEC}/bg_traffic -t $TIMEOUT &
	bg_id=`echo $!`
fi

if [ $nemo_stat -eq 1 ]; then
	#
	# First pass check for obvious errors
	# 1. if the "ipackets" > "rbytes"
	# 2. if the "opackets" > "obytes"
	#
	echo "$TESTNAME:dladm show-link -s"
	dladm show-link -s
	dladm_data=`dladm show-link -s | \
		grep ${LOCAL_INTERFACE}${INTERFACE_NUM}`
	para_cnt=`echo $dladm_data | \
		grep ${LOCAL_INTERFACE}${INTERFACE_NUM} | wc -w`
	if [ $para_cnt -eq 7 ]; then
		int_ipkts=`echo $dladm_data | awk '{print $2}'`
		int_rbyts=`echo $dladm_data | awk '{print $3}'`
		int_opkts=`echo $dladm_data | awk '{print $5}'`
		int_obyts=`echo $dladm_data | awk '{print $6}'`

		echo "$TESTNAME:Checking in pkts with in bytes"
		if [ $int_ipkts -gt $int_rbyts ]; then
			echo "$TESTNAME: Checking Fail"
			echo "$TESTNAME: ${LOCAL_INTERFACE}${INTERFACE_NUM}'s \
				ipackets $int_ipkts > rbytes $int_rbyts"
		else
			echo "$TESTNAME: Checking Pass"
		fi

       		echo "$TESTNAME: Checking out pkts with out bytes"
		if [ $int_opkts -gt $int_obyts ]; then
			echo "$TESTNAME: Checking Fail"
			echo "$TESTNAME: ${LOCAL_INTERFACE}${INTERFACE_NUM}'s \
				opackets $int_opkts > obytes $int_obyts"
		else
			echo "$TESTNAME: Checking Pass"
		fi
	else
		echo "$TESTNAME Fail: Overflow detected in dladm show-link -s"
		echo "		Please check the log file for detail"
	fi
fi
#
# Then check to see if the statistic count increasing correctly
# Not implement yet
#

#
# Check output of netstat, work to do:
# 1. check link speed
# 2. according to link speed, check if packet number overflow
#
linkspeed=`get_linkspeed ${TST_INT} ${TST_NUM}`
if [ "$linkspeed" = "0" ]; then
        echo "can't not get linkspeed"
        exit 1
else
	linkspeed_byte=`expr $linkspeed \* 1000000 / 8`
fi

#
# Considering 64Byte packet when calculating max pkt rates
#
echo "$TESTNAME: netstat overflow check, running $COUNT secs..."
max_pkt_rate=`expr $linkspeed_byte / 64`
TMP_LOG=/tmp/${TESTNAME}.tmp.`date '+%y.%m.%d.%H.%M.%S'`
netstat -I ${LOCAL_INTERFACE}${INTERFACE_NUM} 1 $COUNT > ${TMP_LOG}
line_cnt=1
cat ${TMP_LOG} | grep -v '[a-z]' | while read line; do
	if [ $line_cnt -eq 1 ]; then
		continue
	fi
	input_pkts=`echo $line | awk '{print $1}'`
	outpt_pkts=`echo $line | awk '{print $3}'`
	if [ $input_pkts -gt $max_pkt_rate ]; then
		echo "$TESTNAME:LINE $line_cnt input pkts overflow"
	fi

	if [ $outpt_pkts -gt $max_pkt_rate ]; then
		echo "$TESTNAME: LINE $line_cnt output pkts overflow"
	fi
	line_cnt=`expr $line_cnt + 1`
done

echo "$TESTNAME: kstat -p ${LOCAL_INTERFACE}${INTERFACE_NUM}"
kstat -p ${LOCAL_INTERFACE}:${INTERFACE_NUM}

echo "$TESTNAME: netstat -I ${LOCAL_INTERFACE}${INTERFACE_NUM} -s"
netstat -I ${LOCAL_INTERFACE}:${INTERFACE_NUM} -s

wait $bg_id
echo "TEST $TESTNAME ENDS"
exit 0
