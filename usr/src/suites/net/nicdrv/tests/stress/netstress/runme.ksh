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
# ident	"@(#)runme.ksh	1.3	09/06/24 SMI"
#

###############################################################################
# __stc_assertion_start
# 
# ID: tests/stress/netstress
# 
# DESCRIPTION:
#         Test driver stability by running a heavy network traffic (TCP/UDP)
# 
# STRATEGY:
#         - Generate multi-session TCP/UDP network traffic.
#         - During data transmission, enable/disable promiscuous mode.
#         - After 12-15 hours of testing, the test interface should still work
#           or be recovered correctly.
# 
# TESTABILITY: statistical and implicit
# 
# AUTHOR: Robin.Luo@Sun.COM
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

trap "pkill snoop" 1 2 3 9 15

typeset last_link_state=`dmesg |grep ${TST_INT}${TST_NUM} |sed -n -e '$P'`

fail_flag=0

sess_num=15

PHY_MEM=`prtconf -v | grep "Memory size:" | awk '{print $3}'`
PHY_MEM_RMT=`rsh $RMT_HST "prtconf -v" | grep "Memory size:" | awk '{print $3}'`
# The session number should match the whole test environment
if [ $PHY_MEM_RMT -lt $PHY_MEM ]; then
        PHY_MEM=$PHY_MEM_RMT
fi

if [ $PHY_MEM -lt 1024 ]; then
        sess_num=5
fi

if [ $PHY_MEM -gt 4000 ]; then
        sess_num=30
fi

ARCH=`isainfo -b`
ARCH_RMT=`rsh $RMT_HST "isainfo -b"`
if [ $ARCH -eq 32 -o $ARCH_RMT -eq 32 ]; then
        sess_num=5
fi

data_list="65000 1460 1"
proto_list="TCP_STREAM UDP_STREAM"

RUN_TIME=7000

dtrace_start "99" ${TST_INT}
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

echo "Turning on/off promiscuous mode by using snoop scripts..."
${STF_SUITE}/tools/misc/snoop_onoff &
snoop_id=`echo $!`

for proto_type in $proto_list; do
        for data_size in $data_list; do
		echo "MAXQ.auto $sess_num sessions $proto_type testing"
		echo "Payload is $data_size, runtime: $RUN_TIME" 
                ${STF_SUITE}/tools/maxq/${STF_EXECUTE_MODE}/MAXQ.auto \
			-s $LOCAL_HST -c $RMT_HST -C $RMT_HST \
			-d $data_size -b 65535 -M $subnet_ip \
			-m root@localhost -p nicdrv -i 1 -e $linkspeed \
			-T $RUN_TIME -t 0 -tr bi -S $sess_num \
			-P $proto_type > /dev/null 2>&1
        done
done


echo "Killing snoop processes..."
kill $snoop_id

while true; do
	snoop_list=`pgrep snoop`
	if [ -z "$snoop_list" ]; then
		break;
	else
		echo "Try to kill following snoop process:"
		echo $snoop_list
		pkill -9 snoop
		rsh -l root ${RMT_HST} "pkill snoop"
		sleep 5
	fi
done

pkill -P $cur_pid rsh

check_host_alive $LOCAL_HST $RMT_HST
if [ $? -ne 0 ]; then
        echo "The client isn't alive, Test FAIL!"
	dtrace_end $dtr_pid "99"
        exit ${STF_FAIL}
else
        echo "The client is alive, PASS!" 
fi

#
# Test2: The maximum number of session test
#
ms_run_time="$(get_parameter MAX_SESSIONS_RUN_TIME)"
lost_rate="$(get_parameter NETSTRESS_SESSION_LOST_RATE)"

sess_num=0

if [ "$PHY_MEM" -lt 2048 ]; then
	echo "Max session number test will no run when memory is less than 2G"
elif [ "$PHY_MEM" -lt 4000 ]; then
	sess_num=1000
elif [ "$PHY_MEM" -lt 8000 ]; then
	sess_num=2000
else
	sess_num=3000
fi

# if the kmem_flags is on, cut off the session number 50%
memory_flag=$(echo "kmem_flags/X" | mdb -k | awk '{print $2}')
if [ $memory_flag = "f" ]; then
	echo "kmem_flags=0x" $memory_flag
	sess_num=$(( sess_num / 2 ))
fi

echo "MAXQ.auto $sess_num sessions for $ms_run_time seconds"
${STF_SUITE}/tools/maxq/${STF_EXECUTE_MODE}/MAXQ.auto \
	-s $LOCAL_HST -c $RMT_HST -C $RMT_HST \
        -d 65000 -b 65535 -M $subnet_ip \
        -m root@localhost -p nicdrv -i 1 -e $linkspeed \
        -T $ms_run_time -t 0 -tr bi -S $sess_num \
        -P TCP_STREAM
#
# If the lost_rate is not zero, should check how many sessions failed
#
if [ $? -ne 0 -a $lost_rate -eq 0 ]; then
	echo "Max session number test failed!"
	fail_flag=1
fi

dtrace_end $dtr_pid "99"

#check if there are new messages appears for this interface
typeset count=0
typeset logfile="${STF_RESULTS}/tmp/${TESTNAME}_dmesg.log"

cat /dev/null > $logfile
echo "LAST dmesg: $last_link_state"
test_fail=0

dmesg |grep ${TST_INT}${TST_NUM} |while read line
do
	echo ${line} >> $logfile
	count=`expr $count + 1`
	#If there is "link down message appears for this interface, we consider the test fail"
	echo $line |grep "link down"
	if [ $? -eq 0 ]; then
		test_fail=1
	fi
	# reset logfile, we only care about new messages in system log
        if [ "$line" = "$last_link_state" ]; then
		echo "Find match for last interface messages."
		cat /dev/null > $logfile
		count=0
		test_fail=0
        fi
done

if [ $test_fail -eq 1 ]; then
        echo "Link status unstable. Test FAIL!"
        fail_flag=1
fi

if [ $count -ne 0 ]; then
        echo "WARNING: $count new dmesg appears in system log for this interface."
        echo "***************************************************************"
        cat $logfile
        echo "***************************************************************"
fi

# Check chip reset count, should not increase
check_reset_count ${TST_INT} ${TST_NUM}
if [ $? -eq 1 ]; then
        echo "WARNING! The number of chip reset count increased."
fi

check_host_alive $LOCAL_HST $RMT_HST
if [ $? -ne 0 ]; then
	echo "The client isn't alive, Test FAIL!"
	fail_flag=1
else
	echo "The client is alive, PASS!" 
fi

if [ $fail_flag -eq 1 ]; then
	echo "netstress test FAIL!"
	exit ${STF_FAIL}
fi

exit ${STF_PASS}
