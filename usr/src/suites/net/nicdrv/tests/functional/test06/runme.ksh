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
# ident	"@(#)runme.ksh	1.7	09/06/24 SMI"
#

#
# This test case is to set every working duplex/speed mode of driver
# And run TCP/UDP performance benchmark for 5 mins in each mode
# For typical 10G card, the test will direct return with STF_PASS without 
# perf result
# if driver does not support ndd, it will return STF_UNSUPPORTED
#

###############################################################################
# __stc_assertion_start
# 
# ID: tests/functional/test06
# 
# DESCRIPTION:
#         Test data transmit/receive functionality
#         on all of duplex/speed modes supported by driver
# 
# STRATEGY:
#         - Set all duplex/speed modes
#           (dup/1000 half/1000 dup/100 half/100 dup/10 half/10)
#         - On each mode, run multi-session TCP traffic with
#           different payloads (65000/1460/1 bytes).
#         - On each mode, run multi-sessions UDP traffic with
#           different payloads (65000/1460/1 bytes).
#         - All operations should pass without any errors.
#         - Driver link/speed status should be recovered to original status.
# 
# TESTABILITY: implicit
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

#
# Restore original speed mode
# $1 the original speed
#
restore_speed()
{
	#
	# Restore original ndd parameters
	#
	cat /tmp/ndd_tmp.log | while read NEWLINE; do
        	ndd_para=`echo $NEWLINE | awk '{print $1}'`
        	ndd_value=`echo $NEWLINE | awk '{print $2}'`
        	ndd -set /dev/${TST_INT}${TST_NUM} $ndd_para $ndd_value
	done

	check_host_alive $LOCAL_HST $RMT_HST
	if [ $? -ne 0 ]; then
        	echo "The link isn't up, restore failed!"
		return 1
	fi

	echo "show ${TST_INT}${TST_NUM} nic card info"
	show_device | grep ${TST_INT}${TST_NUM}
	cur_speed=`get_linkspeed ${TST_INT} ${TST_NUM}`
	if [ $cur_speed != $1 ]; then
		echo "Current speed is $cur_speed, recover failed"
		return 1
	fi

	return 0
}


save_speed()
{
	if [ -f /tmp/ndd_tmp.log ]; then
		rm /tmp/ndd_tmp.log
	fi
	
	# Possible support mode list, don't change it
	mode_list="1000fdx 1000hdx 100fdx 100hdx 10fdx 10hdx"

	save_count=0
	for each in $mode_list; do
		ret_num=`ndd /dev/${TST_INT}${TST_NUM} \? | \
	    	    grep adv_${each}_cap | grep write | wc -l`
		if [ $ret_num -eq 1 ]; then
			echo "adv_${each}_cap matched..."
			save_count=`expr $save_count + 1`
        		old_ndd_para_value=`ndd /dev/${TST_INT}${TST_NUM} \
	        	    adv_${each}_cap`
        		echo "adv_${each}_cap $old_ndd_para_value" >> \
			    /tmp/ndd_tmp.log
		fi
	done

	echo "$save_count modes matched and saved"
	return 0
}

set_speed()
{
	# Possible support mode list, don't change it
	mode_list="1000fdx 1000hdx 100fdx 100hdx 10fdx 10hdx"

	echo "now set adv_${1}_cap..."
        ndd -set /dev/${TST_INT}${TST_NUM} adv_${1}_cap 1

	set_count=0
	for mode in $mode_list; do
		if [ "${1}" != "${mode}" ]; then
			ret_num=`ndd /dev/${TST_INT}${TST_NUM} \? | \
	    	    	grep adv_${mode}_cap | grep write | wc -l`
			if [ $ret_num -eq 1 ]; then
				echo "adv_${mode}_cap cleared..."
				set_count=`expr $set_count + 1`
				ndd -set /dev/${TST_INT}${TST_NUM} \
					adv_${mode}_cap 0
			fi
		fi
	done
	echo "$set_count modes cleared"

	#
	# Make sure remote host is alive
	#
	check_host_alive $LOCAL_HST $RMT_HST
	if [ $? -ne 0 ]; then
		echo "The link isn't up"
		echo "after ndd -set adv_${each}_cap 1"
		return 1
	fi
	
	echo "show ${TST_INT}${TST_NUM} nic card info"
	show_device | grep ${TST_INT}${TST_NUM}
        expect_speed=`echo adv_${1}_cap | sed 's/[a-zA-Z_]*//g'`

        cur_speed=`get_linkspeed ${TST_INT} ${TST_NUM}`
        if [ $cur_speed != $expect_speed ]; then
           	echo "Speed doesn't match:"
		echo "Current speed is $cur_speed"
		echo "But ndd operation is ndd -set adv_${each}_cap 1."
		echo "We expect speed is $expect_speed."
		return 1
        fi

	return 0
}

run_maxq()
{
	RUN_TIME=`get_parameter MAXQ2_RUN_TIME`
	data_list=`get_parameter MAXQ2_DATA_SIZE`

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

	if [ $PHY_MEM -le 2048 ]; then
       		sess_num=4
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

	echo "adv_${each}_cap: test of TCP/UDP traffic begins"
        #
        # Run MAXQ with TCP and UDP
        #
	RET_FLAG=0
        for data_size in $data_list; do
		${STF_SUITE}/tools/maxq/${STF_EXECUTE_MODE}/MAXQ.auto \
		    -s $LOCAL_HST -c $RMT_HST -C $RMT_HST \
		    -d $data_size -b 65535 -M $subnet_ip \
		    -m root@localhost -p nicdrv -i 1 \
		    -e $linkspeed -T $RUN_TIME -t 0 -tr bi \
		    -S $sess_num -P TCP_STREAM

		if [ $? -ne 0 ]; then
			RET_FLAG=1
		fi
	done
	sess_num=1
        for data_size in $data_list; do
		${STF_SUITE}/tools/maxq/${STF_EXECUTE_MODE}/MAXQ.auto \
		    -s $LOCAL_HST -c $RMT_HST -C $RMT_HST \
		    -d $data_size -b 65535 -M $subnet_ip \
		    -m root@localhost -p nicdrv -i 1 \
		    -e $linkspeed -T $RUN_TIME -t 0 -tr rx \
		    -S $sess_num -P UDP_STREAM

		if [ $? -ne 0 ]; then
			RET_FLAG=1
		fi
	done
        for data_size in $data_list; do
		${STF_SUITE}/tools/maxq/${STF_EXECUTE_MODE}/MAXQ.auto \
		    -s $LOCAL_HST -c $RMT_HST -C $RMT_HST \
		    -d $data_size -b 65535 -M $subnet_ip \
		    -m root@localhost -p nicdrv -i 1 \
		    -e $linkspeed -T $RUN_TIME -t 0 -tr tx \
		    -S $sess_num -P UDP_STREAM

		if [ $? -ne 0 ]; then
			RET_FLAG=1
		fi
	done
        echo "adv_${each}_cap: test of TCP/UDP traffic ends"
	if [ $RET_FLAG -ne 0 ]; then
		return 1
	fi
	return 0
}

# Main
dtrace_start "06" ${TST_INT}
dtr_pid=`echo $!`

ndd /dev/${TST_INT}${TST_NUM} \? > /dev/null

if [ $? -ne 0 ]; then
	echo "Test interface does not support ndd"
	exit ${STF_UNSUPPORTED}
fi

orig_speed=`get_linkspeed ${TST_INT} ${TST_NUM}`
echo "original speed is $orig_speed..."

if [ "$orig_speed" != "1000" ] &&
    [ "$orig_speed" != "100" ] &&
    [ "$orig_speed" != "10" ]; then
	echo "The speed mode is not support by this case"
	dtrace_end $dtr_pid "06"
	exit ${STF_UNSUPPORTED}
fi

save_speed

trap "restore_speed $orig_speed; exit 1" 1 2 3 9 15

# Record the current chip reset number
record_reset_count ${TST_INT} ${TST_NUM}

#
# Test mode list, you can change it, if some modes have bug
# test_mode="1000fdx 1000hdx 100fdx 100hdx 10fdx 10hdx"
# It seems some 1Gbps driver doesn't support 1000hdx, so we
# have to remove 1000hdx in test mode
#
test_mode=`get_parameter TEST_MODE`

FAIL_FLAG=0
match_count=0
for each in $test_mode; do
	ret_num=`ndd /dev/${TST_INT}${TST_NUM} \? | \
	    grep adv_${each}_cap | grep write | wc -l`
	if [ $ret_num -eq 1 ]; then
		echo "adv_${each}_cap matched..."
		match_count=`expr $match_count + 1`
        	echo "now set_speed adv_${each}_cap..."
        	set_speed ${each}
		if [ $? -ne 0 ]; then
			FAIL_FLAG=1
		else
			echo "Running maxq at ${each} ......" 
			run_maxq
			if [ $? -ne 0 ]; then
				FAIL_FLAG=1
			fi
		fi

	fi
done

if [ $match_count -eq 0 ]; then
	echo "Only current speed mode test..."
	run_maxq
else
	restore_speed $orig_speed
	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
	fi
fi

# Check chip reset count, should not increase
check_reset_count ${TST_INT} ${TST_NUM}
if [ $? -eq 1 ]; then
        echo "The number of chip reset count increased. FAIL!"
        FAIL_FLAG=1
fi

dtrace_end $dtr_pid "06"

if [ $FAIL_FLAG -ne 0 ]; then
	exit ${STF_FAIL}
fi

exit ${STF_PASS}
