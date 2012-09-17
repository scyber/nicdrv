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
# ident	"@(#)runme.ksh	1.6	09/06/24 SMI"
#

###############################################################################
# __stc_assertion_start
# 
# ID: tests/functional/test01
# 
# DESCRIPTION:
#         Test data transmit/receive functionality under promiscuous mode
# 
# STRATEGY:
#         - Start multi-session TCP traffic with 65000/1460/1 byte payloads
#         - During TCP data bi transmission, repeatedly enable/disable promiscuous mode
#         - Start multi-session UDP traffic with 65000/1460/1 byte payloads
#         - During UDP data rx/tx transmission, repeatedly enable/disable promiscuous mode
#         - All TCP/UDP sessions should pass without any errors
# 
# TESTABILITY: statistical and implicit
# 
# AUTHOR: Oliver.Yang@Sun.COM
# 
# REVIEWERS:
# 
# TEST AUTOMATION LEVEL: automated
# 
# CODING_STATUS:  COMPLETED (2006-05-10)
# 
# __stc_assertion_end
# 
###############################################################################

. ${STF_TOOLS}/include/stf_common.kshlib
. ${STF_SUITE}/include/common.kshlib

# Define local variables
readonly ME=$(whence -p ${0})

# Extract and print assertion information from this source script to journal
extract_assertion_info $ME

check_host_alive $LOCAL_HST $RMT_HST
if [ $? -ne 0 ]; then
	echo "The client isn't alive!"
	exit ${STF_UNRESOLVED}
fi

trap "pkill snoop; pkill MAXQ.auto; exit 1" 1 2 3 9 15

data_list="65000 1460 1"
data_list=`get_parameter MAXQ_DATA_SIZE`
RUN_TIME=`get_parameter MAXQ_RUN_TIME`
RUN_TIME_UDP=`get_parameter MAXQ_UDP_RUN_TIME`

sess_num=5

PHY_MEM=`prtconf -v | grep "Memory size:" | awk '{print $3}'`
PHY_MEM_RMT=`rsh $RMT_HST "prtconf -v" | grep "Memory size:" | awk '{print $3}'`
# The session number should match the whole test environment
if [ $PHY_MEM_RMT -lt $PHY_MEM ]; then
	PHY_MEM=$PHY_MEM_RMT
fi

if [ $PHY_MEM -lt 1024 ]; then
	sess_num=2
fi

if [ $PHY_MEM -gt 4000 ]; then
	sess_num=10
fi

if [ $PHY_MEM -gt 8000 ]; then
	sess_num=20
fi

ARCH=`isainfo -b`
ARCH_RMT=`rsh $RMT_HST "isainfo -b"`
if [ $ARCH -eq 32 -o $ARCH_RMT -eq 32 ]; then
	sess_num=`expr $sess_num / 2`
fi

dtrace_start "01" ${TST_INT}
dtr_pid=`echo $!`
cur_pid=`echo $$`

linkspeed=`get_linkspeed ${TST_INT} ${TST_NUM}`
if [ "$linkspeed" = "0" ]; then
        echo "can't not get linkspeed"
        exit ${STF_FAIL}
fi

subnet_ip=`get_subnetip ${TST_INT} ${TST_NUM}`
if [ "$subnet_ip" = "0" ]; then
        echo "can't not get subnet_ip"
        exit ${STF_FAIL}
fi

# Record the current chip reset number
record_reset_count ${TST_INT} ${TST_NUM}

#
# Turning on/off promiscuous mode will generate
# some interoperations in the driver. Verify the
# driver is stable.
#
echo "Turning on/off promiscuous mode by using snoop scripts..."
${STF_SUITE}/tools/misc/snoop_onoff &
snoop_id=`echo $!`

FAIL_FLAG=0
for data_size in $data_list; do

	${STF_SUITE}/tools/maxq/${STF_EXECUTE_MODE}/MAXQ.auto \
	    -s $LOCAL_HST -c $RMT_HST -C $RMT_HST \
	    -d $data_size -b 65535 -M $subnet_ip \
	    -m root@localhost -p nicdrv -i 1 -e $linkspeed \
	    -T $RUN_TIME -t 0 -tr bi -S $sess_num -P TCP_STREAM

	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
	fi

done

sess_num=1

for data_size in $data_list; do

	${STF_SUITE}/tools/maxq/${STF_EXECUTE_MODE}/MAXQ.auto \
	    -s $LOCAL_HST -c $RMT_HST -C $RMT_HST \
	    -d $data_size -b 65535 -M $subnet_ip \
	    -m root@localhost -p nicdrv -i 1 -e $linkspeed \
	    -T ${RUN_TIME_UDP} -t 0 -tr rx -S $sess_num -P UDP_STREAM

	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
	fi

done

for data_size in $data_list; do

	${STF_SUITE}/tools/maxq/${STF_EXECUTE_MODE}/MAXQ.auto \
	    -s $LOCAL_HST -c $RMT_HST -C $RMT_HST \
	    -d $data_size -b 65535 -M $subnet_ip \
	    -m root@localhost -p nicdrv -i 1 -e $linkspeed \
	    -T ${RUN_TIME_UDP} -t 0 -tr tx -S $sess_num -P UDP_STREAM

	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
	fi

done


check_host_alive $LOCAL_HST $RMT_HST
if [ $? -ne 0 ]; then
	echo "The client isn't alive, Test FAIL!"
	FAIL_FLAG=1
else
	echo "The client is alive!"
fi
# Check chip reset count, should not increase
check_reset_count ${TST_INT} ${TST_NUM}
if [ $? -eq 1 ]; then
        echo "The number of chip reset count increased. FAIL!"
        FAIL_FLAG=1
fi

echo "Killing snoop processes..."
kill $snoop_id

while true; do
        snoop_list=`pgrep snoop`
        if [ -z "$snoop_list" ]; then
                break;
        else
                echo "Try to kill the following snoop processes:"
                echo $snoop_list
                pkill -9 snoop
		rsh -l root ${RMT_HST} "pkill snoop"
                sleep 5
        fi
done

pkill -P $cur_pid rsh

dtrace_end $dtr_pid "01"

if [ $FAIL_FLAG -ne 0 ]; then
	exit ${STF_FAIL}
fi

exit ${STF_PASS}
