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
# ident	"@(#)runme.ksh	1.3	09/06/24 SMI"
#

###############################################################################
# __stc_assertion_start
#
# ID: tests/functional/test13
#
# DESCRIPTION:
#         NIC driver parameter configuration testing via dladm command(Brussles project)
#
# STRATEGY:
#         - List all parameters for the NIC device via dladm
#         - For each parameter, try to set the parameter to all possible value. 
#		check if the parameter is read-only or not-supported.  
#         - Reset each parameter and verify the value is reset to its default value
#         - Use dladm to set the link speed to 1000M, 100M, 10M and run MAXQ
#         - Use dladm to set the mtu to 1500, 9000
#
# TESTABILITY: statistical and implicit
#
# AUTHOR: mengwei.jiao@sun.com
#
# REVIEWERS:
#
# TEST AUTOMATION LEVEL: automated
#
# CODING_STATUS:  COMPLETED (2008-05-30)
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


#
# exit test with an error message and status
# $1 error message
# $2 return code
#
exit_test()
{
	echo $1
	# Delete the temporary file
	rm $g_bak

	dtrace_end $dtr_pid "06"

	if [ $FAIL_FLAG -ne 0 ]; then
		exit ${STF_FAIL}
	fi

	exit $STF_PASS
}

#
# print error message and current NIC property when test fail
# $1 error message 
#
fail()
{
	FAIL_FLAG=1
	cleanup
	exit_test "$1" 
}

#
# cleanup interface property and restore interface
#
cleanup()
{
	typeset result=0
        echo "Clean up, try to restore test interface."

	# display current interface 
	echo "dladm show-linkprop ${TST_INT}${TST_NUM}"
	dladm show-linkprop ${TST_INT}${TST_NUM}

	restore_interface ${TST_INT}${TST_NUM}
	# in STF framework, restore_prop can't finish within timeframe allowed.
	restore_prop

        echo "Clean up done!"
}

#
# restore NIC interface properties from a file
# $g_bak the backup file name 
#
restore_prop()
{
	
	typeset result=0

        if [ ! -f $g_bak ]; then
		echo "Warning: Can not find interface property backup file."
		return 1 
        fi

	#
	# Restore original property value
	#
	cat $g_bak | while IFS=: read TYPE LINK PROPERTY PERM VALUE DEFAULT POSSIBLE; do
		old_value=$VALUE
		if [[ "$PERM" != "rw" ]]; then
			continue
		fi
		if [ "$TYPE" = "t" ]; then
			type_t="-t"
			type_p=""
		else
			type_t=""
			type_p="-P"
		fi

		VALUE=$(dladm show-linkprop $type_p -o VALUE -cp $PROPERTY ${TST_INT}${TST_NUM})

		# The current value is the same as the orginal value
		# continue to the next property
		if [ "$VALUE" = "$old_value" ]; then
			continue
		fi

		# Restore the property value
		# -- means not set, ? means unknown
		if [[ "$VALUE" != "--"  && "$VALUE" != "?" ]]; then
			dladm set-linkprop $type_t -p $PROPERTY=$old_value ${TST_INT}${TST_NUM} > /dev/null 2>&1
		else
			dladm reset-linkprop $type_t -p $PROPERTY ${TST_INT}${TST_NUM} > /dev/null 2>&1
		fi
		if [ $? -ne 0 ]; then
			echo "Failed to restore $PROPERTY to $old_value"
			result=1
		fi
		
	done
	return $result
}



#
# save current dladm properties to a file
# $1 the backup file name
#
save_prop()
{
	if [ -f $g_bak ]; then
		rm $g_bak
	fi

	#save all temporary properties
	dladm show-linkprop -c -o LINK,PROPERTY,PERM,VALUE,DEFAULT,POSSIBLE ${TST_INT}${TST_NUM} | while read line; do
		echo "t:"$line >> $g_bak
	done

	# skip persistent property testing, it is not close related to driver.
	# It has the save coverage as the temporary property value testing
	#

	return 0
}


#
# set mtu using dladm command for remote host
# $1 remote host name
# $2 driver name for the interface
# $3 instance number for the interface
# $4 mtu value to be set
#
set_mtu_remote()
{
	typeset host=$1
	typeset driver=$2
	typeset int_num=$3
	typeset mtu_value=$4
	
	rcp  ${STF_SUITE}/tests/functional/test13/set_mtu $host:/tmp || { echo can not copy set_mtu to remote host $host; return 1; }

        exec_rshcmd $host "/tmp/set_mtu $driver $int_num $mtu_value"
}

#
# Set mtu using dladm command
# $1 interface name
# $2 mtu value to be set
#
set_mtu()
{
	
	typeset interface=$1
	typeset mtu_value=$2

	dladm set-linkprop -tp mtu=$mtu_value $interface || return 1

	# verify the mtu value 
	VALUE=$(dladm show-linkprop -c -o VALUE -p mtu $interface)

	if [ "$VALUE" != "$mtu_value" ]; then
		return 1
	fi
			
	return 0

}

#
# Set remote interface speed using dladm command
#
#
set_speed_remote()
{
	exec_rshcmd ${RMT_HST} "dladm set-linkprop -t -pen_${1}_cap=1 ${RMT_INT}${RMT_NUM}"
}

#
# Set inteface speed using dladm command
# $1 interface speed (such as 1000fdx, 1000hdx, 100fdx...)
#
set_speed()
{

	# All possible mode list, don't change it
	mode_list=`get_parameter SUPPORTED_SPEED_MODE`
	echo $mode_list | grep -w ${1} || { echo "Can not find mode in supported mode."; return 1; }

	# enable the mode for the speed to be set
        dladm set-linkprop -t -pen_${1}_cap=1 ${TST_INT}${TST_NUM}
	if [ $? -ne 0 ]; then
		echo "ERROR: can not set en_${1}_cap."	
		return 1
	fi

	# clear all other modes
	set_count=0
	for mode in $mode_list; do
		if [ "${1}" != "${mode}" ]; then
			dladm set-linkprop -tp en_${mode}_cap=0 ${TST_INT}${TST_NUM}
			if [ $? -eq 0 ]; then
				set_count=`expr $set_count + 1`
			else
				echo "adv_${mode}_cap can not be cleared"
				
			fi
		fi
	done
	echo "$set_count modes in `echo $mode_list | wc | awk '{print $2}'` modes cleared"
	#dladm show-linkprop bge0

	# waiting for NIC negotiation.
	sleep 20


	# verify the current speed is the same as what we set
        expect_speed=`echo ${1} | sed 's/[a-zA-Z_]*//g'`
	
        cur_speed=`get_linkspeed_dladm ${TST_INT}${TST_NUM}`
        if [ "$cur_speed" != "$expect_speed" ]; then
           	echo "Speed doesn't match:"
		echo "Current speed is $cur_speed"
		echo "We expect speed is $expect_speed."
		return 1
        fi

	echo "dladm show-ether ${TST_INT}${TST_NUM}"
	dladm show-ether ${TST_INT}${TST_NUM}

	#
	# Make sure remote host is alive
	#
	check_host_alive $LOCAL_HST $RMT_HST
	if [ $? -ne 0 ]; then
		fail "The link isn't up after setting to $1 mode"
	fi

	return 0
}

#
#get current mtu value
#
get_mtu()
{
	VALUE=$(dladm show-linkprop -c -o VALUE -p mtu $1)
	if [ $? -ne 0 ]; then
		echo "ERROR: can not get dladm mtu property"
		return 1
	fi
	if [ -z "$VALUE" -o "$VALUE" = "?" -o "$VALUE" = "--" ]; then
		echo "ERROR: dladm mtu value is null"
		return 1
	fi
	echo $VALUE
	return 0

}

#
# get current link speed 
#
get_linkspeed_dladm()
{
	# get link speed via dladm show-linkprop
	# the output is a number like 1000
	speed1=$(dladm show-linkprop -c -o VALUE -p speed $1)
	if [ $? -ne 0 ]; then
		echo "ERROR: can not get link speed, dladm show-linkprop -c -p speed $1"
		return 1
	fi

	# get link speed via dladm show-dev/show-phys
	# the output is like 100Mb 1000Mb
	speed2=$(show_device "-p $1 -o SPEED")
	if [ $? -ne 0 ]; then
		echo "ERROR: can not get link speed, dladm show-dev/show-phys -p $1 "
		return 1
	fi
	speed2=`echo $speed2 | sed 's/[a-zA-Z_\-]*//g'`

	# get link speed via dladm show-ether
	# the output is in SPEED-DUPLEX format like 100M-f 1G-f
	speed3=$(dladm show-ether -p $1 -o SPEED-DUPLEX |cut -d - -f1) 
        if [ $? -ne 0 ]; then
                echo "ERROR: can not get link speed, dladm show-ether -p $1 "
                return 1
        fi

	#change 1G, 10G to 1000, 10000G
        speed3=`echo ${speed3} | sed 's/G/000/'`

	# remove extra char like "M", "_"
        speed3=`echo ${speed3} | sed 's/[a-zA-Z_]*//g'`

	# verify all the speed match each other
	if [ "$speed1" = "$speed2" -a "$speed1" = "$speed3" ]; then
		echo $speed1
		return 0
	else
		echo "ERROR: speed does not match, $speed1, $speed2, $speed3"
		return 1
	fi
}

#
# run MAXQ
#
run_maxq()
{
	RUN_TIME=`get_parameter MAXQ13_RUN_TIME`
	data_list=`get_parameter MAXQ13_DATA_SIZE`

	tcp_sess_num=`get_parameter MAXQ13_TCP_SESSION`

	subnet_ip=`get_subnetip ${TST_INT} ${TST_NUM}`
	if [ "$subnet_ip" = "0" ]; then
		fail "can not get subnet_ip"
	fi

	linkspeed=`get_linkspeed_dladm ${TST_INT}${TST_NUM}`
	echo "adv_${each}_cap: test of TCP/UDP traffic begins"
        #
        # Run MAXQ 
        #
	RET_FLAG=0
        for data_size in $data_list; do
		${STF_SUITE}/tools/maxq/${STF_EXECUTE_MODE}/MAXQ.auto \
		    -s $LOCAL_HST -c $RMT_HST -C $RMT_HST \
		    -d $data_size -b 65535 -M $subnet_ip \
		    -m root@localhost -p nicdrv -i 1 \
		    -e $linkspeed -T $RUN_TIME -t 0 -tr bi \
		    -S $tcp_sess_num -P TCP_STREAM

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

#
#run ping test
#
run_ping()
{
	typeset test_result=0

	if [ "$RUN_MODE" =  "ONPIT" ]; then
		# Simple ping check
		echo "simple ping check"
		for icmp_payload in 0 1 1472 1473 9000 65007; do
			#
			# Only when ICMP payload > 8 bytes, it could
			# print RTT. It does not matter
			#
			ping -s $RMT_HST $icmp_payload 1 > /dev/null
			if [ $? -ne 0 ]; then
				echo "ping: payload $icmp_payload failed"
				test_result=1
			fi
		done
		# 65508 negative case
		echo "negative case: ping with payload 65508"
		icmp_payload=65508
		ping -s $RMT_HST $icmp_payload 1 > /dev/null
		if [ $? -eq 0 ]; then
			echo "ping: payload $icmp_payload test failed"
			test_result=1
		fi
	else
		# Normal ping check
		echo ${STF_SUITE}/tools/ping/Ping.auto \
		    -i ${TST_INT}${TST_NUM} -r ${RMT_INT}${RMT_NUM} \
		    -c ${RMT_HST} -h ${LOCAL_HST}
		${STF_SUITE}/tools/ping/Ping.auto \
		    -i ${TST_INT}${TST_NUM} -r ${RMT_INT}${RMT_NUM} \
		    -c ${RMT_HST} -h ${LOCAL_HST}

		if [ $? -ne 0 ]; then
			echo  "ping test failed!"
			test_result=1
		else
			echo  "ping test succeed!"
		fi
	fi
	return $test_result

}


run_corrupt()
{
	typeset test_result=0
	typeset run_time=$(get_parameter NFS13_RUN_TIME)

	if [ "$RUN_MODE" !=  "ONPIT" ]; then
		echo ${STF_SUITE}/tools/nfscorrupt/${STF_EXECUTE_MODE}/Corrupt.auto \
			-c $RMT_HST -s $LOCAL_HST -n 1 -t $run_time \
			-d bi -e "root@localhost" -p $TST_INT -m tcp -r no
		${STF_SUITE}/tools/nfscorrupt/${STF_EXECUTE_MODE}/Corrupt.auto \
			-c $RMT_HST -s $LOCAL_HST -n 1 -t $run_time \
			-d bi -e "root@localhost" -p $TST_INT -m tcp -r no

		if [ $? -ne 0 ]; then
			echo  "nfscorrupt tcp test failed!"
			test_result=1
		else
			echo  "nfscorrupt tcp test succeed!"
		fi
	fi

	echo ${STF_SUITE}/tools/nfscorrupt/${STF_EXECUTE_MODE}/Corrupt.auto \
		-c $RMT_HST -s $LOCAL_HST -n 1 -t $run_time \
		-d bi -e "root@localhost" -p $TST_INT -m udp -r no
	${STF_SUITE}/tools/nfscorrupt/${STF_EXECUTE_MODE}/Corrupt.auto \
		-c $RMT_HST -s $LOCAL_HST -n 1 -t $run_time \
		-d bi -e "root@localhost" -p $TST_INT -m udp -r no


	if [ $? -ne 0 ]; then
		echo  "nfscorrupt udp test failed!"
		test_result=1
	fi
	return $test_result

}

#
# Check if the driver support jumbo frame,
# Currently all driver not supporting jumbo frame should be listed in paramerters.env file
# under NO_JUMBO_SUPPORT keyword
#
support_jumbo()
{
	driver=$1
	list=`get_parameter NO_JUMBO_SUPPORT`
	echo $list |grep -w $driver > /dev/null 2>&1 && return 1
	return 0
	
}

#
# main function start here
#

# Check whether the driver supports Brussels 
support_check=0
if [ "$RUN_MODE" != "WiFi" ]; then
	dladm show-linkprop ${TST_INT}${TST_NUM} | grep "flowctrl" > /dev/null \
	    && support_check=1
else
# For non-ethernet drivers like WiFi, should use other way to check.
	echo "::walk mac_impl_cache|::print mac_impl_t mi_callbacks->mc_setprop" \
	| mdb -k | grep "${TST_INT}_m_setprop" > /dev/null && support_check=1
fi
if [ "$support_check" -eq 0 ]; then
	echo "$TST_INT cannot support dladm test"
        exit $STF_UNSUPPORTED
else
        echo "$TST_INT supports dladm test13"
fi

# Define the untest property, <driver>:<property>
untest_property="e1000g:en_1000hdx_cap"
warn_property=""

FAIL_FLAG=0
g_bak=/tmp/linkprop.$$.${TST_INT}${TST_NUM}

dtrace_start "06" ${TST_INT}
dtr_pid=`echo $!`

trap "fail 'interrupted'"  1 2 3 5 13

# save interface information
save_interface ${TST_INT}${TST_NUM} || fail "Error save interface"

# save current dladm property for the interface
save_prop 


#
# general property testing
#

cat $g_bak | while IFS=: read  TYPE LINK PROPERTY PERM VALUE DEFAULT POSSIBLE
do
	# skip the untest property for the known issue, lt
	echo $untest_property | grep "${TST_INT}:$PROPERTY" > /dev/null \
	        && { echo "Skip $PROPERTY"; continue; }
	#prepare the type parameter for set-linkprop and show-linkprop
	if [ "$TYPE" = "t" ]; then
		type_t="-t"
		type_p=""
	else
		type_t=""
		type_p="-P"
	fi
	# if the property is read only, just run show-linkprop and continue to next
	if [[ "$PERM" != "rw" ]]; then
		old_value=$VALUE
		VALUE=$(dladm show-linkprop $type_p -o VALUE -cp $PROPERTY ${TST_INT}${TST_NUM})

		if [ "$VALUE"  != "$old_value" ]; then
			echo "WARNING: link property $PROPERTY changed."	
		fi
		continue
	fi
	if [[ "$POSSIBLE" = "--" ]]; then
		POSSIBLE=""
	fi

	# get all possible value for a property
	# the dladm output is seperated by "," and "-"(for value range)
	POSSIBLE=`echo $POSSIBLE | sed 's/[,-]/ /g'`

	# add current property value to POSSIBLE value
	if [ "$VALUE" != "--" -a "$VALUE" != "?" -a -n "$VALUE" ]; then
		echo $POSSIBLE |grep $VALUE > /dev/null || POSSIBLE="$POSSIBLE $VALUE"
	fi

	# test reset-linkprop
	# for persistent value, the reset-linkprop may reset the persistent value
	# to blank.
	# for temporary value, the reset-linkprop may reset the value to default
	# as there is no critirea specified, we will just run reset-linkprop
	# without verifying the result.
	if [[ -z "$DEFAULT" || "$DEFAULT" = "--" ]]; then
		dladm reset-linkprop $type_t -p $PROPERTY $LINK  >/dev/null  2>&1
	else
		# add the default value to possible value
		echo $POSSIBLE |grep $DEFAULT > /dev/null || POSSIBLE="$POSSIBLE $DEFAULT"
		dladm reset-linkprop $type_t -p $PROPERTY $LINK >/dev/null 2>&1
	fi

	if [ $? -ne 0 ]; then
		reset_fail_prop="$reset_fail_prop $PROPERTY"
	fi

	#if there is no possible value for a property, just try any value.
	if [ -z "$POSSIBLE" ]; then
		value_unknown_prop="$value_unknown_prop $PROPERTY" 
		dladm set-linkprop $type_t -p $PROPERTY=unknown $LINK >/dev/null 2>&1
		continue
	fi

	#set the property to all possible values, and record the test result
	count=0
	failed_count=0

	for each in $POSSIBLE; do
		count=`expr $count + 1`

		error_msg=`dladm set-linkprop $type_t -p $PROPERTY=$each $LINK 2>&1 `

		if [ $? -ne 0 ]; then 
			failed_count=`expr $failed_count + 1 `
		else
			# verify the setting is successful using dladm show-linkprop
			VALUE=$(dladm show-linkprop $type_p -cp $PROPERTY -o VALUE $LINK)
			if [ "$VALUE" != "$each" ]; then
				# skip warning property
				echo $warn_property | grep "${TST_INT}:$PROPERTY" > /dev/null
				if [ $? -eq 0 ]; then
					echo "WARNING: $PROPERTY should be $each not $VALUE"
				else	
					FAIL_FLAG=1
					failed_count=`expr $failed_count + 1 `
					echo "ERROR: dladm set-linkprop $type_t -p $PROPERTY=$each $LINK ($VALUE)"
					failed_prop="$failed_prop $PROPERTY"
				fi
				break
			else
				continue
			fi
			
		fi	

		# if this is the first time we see the error for this property
		# record the property according to the error message
		[ $failed_count -ne 1 ] && continue

		error_msg=`echo $error_msg |sed s/\'/\"/g`
		if echo $error_msg | grep "operation not supported" >/dev/null; then
			not_supported_prop="$not_supported_prop $PROPERTY"
		elif echo $error_msg | grep "invalid argument" >/dev/null; then
			FAIL_FLAG=1
			echo "ERROR: unable set property to possible value: dladm set-linkprop $type_t -p $PROPERTY=$each $LINK"
			failed_prop="$failed_prop $PROPERTY"		
		else
			#unknown error
			echo "WARNING: unknown error message dladm set-linkprop $type_t -p $PROPERTY=$each $LINK; $error_msg" 
			error_unknown_prop="$unknown_error_prop $PROPERTY"	

		fi
	done

	# setting property to a possible value should all be successs or all fail
	if [ $failed_count -gt 0 -a $failed_count -ne $count ]; then
		echo "WARNING: inconsistent result setting $PROPERTY to $POSSIBLE"
		failed_prop="$failed_prop $PROPERTY"
	fi
	
	if [ "$failed_count" -eq 0 -a "$DEFAULT" != "--" ]; then
		dladm reset-linkprop $type_t -p $PROPERTY $LINK	>/dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo "ERROR: reset command failed dladm reset-linkprop $type_t -p $PROPERTY $LINK"
			failed_prop="$failed_prop $PROPERTY"
		else 
			VALUE=$(dladm show-linkprop $type_p -cp $PROPERTY -o VALUE $LINK)
			# for persistent value, it is reset to blank.
			if [ "$type_p" = "-p" -a -n "$VALUE" ]; then
				echo "ERROR: reset value fail dladm reset-linkprop $type_t -p $PROPERTY $LINK "
				echo "dladm show-linkprop $type_p -cp $PROPERTY -o VALUE $LINK"
				failed_prop="$failed_prop $PROPERTY"
				FAIL_FLAG=1
			fi

			# for temporary property, the value should be reset to default value. 
			if [ "$VALUE" != "$DEFAULT" ]; then
				echo "ERROR: reset value do not equal to default value dladm reset-linkprop $type_t -p $PROPERTY $LINK "
				echo "dladm show-linkprop $type_p -cp $PROPERTY -o VALUE $LINK"
				failed_prop="$failed_prop $PROPERTY"
				FAIL_FLAG=1
			fi
		fi
	fi
	
done
for prop in reset_fail_prop value_unknown_prop failed_prop read_only_prop not_supported_prop error_unknown_prop
do
	eval "echo WARNING: $prop: \$$prop"
done

# restore interface property, As some property value is changed as the result of changing another property.
# e.g. adv_10hdx_cap is a read-only property, its value is changed by setting en_10hdx_cap
# so The test will continue if the restore_prop return 1
# 
restore_prop  

restore_interface  ${TST_INT}${TST_NUM} || fail "Can not restore the test interface."


#
# Make sure remote host is alive
#
check_host_alive $LOCAL_HST $RMT_HST
if [ $? -ne 0 ]; then
	fail "The link isn't up after general property testing."
fi


test_mode=`get_parameter TEST_SPEED_MODE`

echo Current link speed is `get_linkspeed_dladm ${TST_INT}${TST_NUM}`

for each in $test_mode; do
	# check if the mode is supported by driver
	ret_num=`ndd /dev/${TST_INT}${TST_NUM} ${each}_cap`
	if [ $? -eq 0 -a $ret_num -eq 1 ]; then

		# Try enable the remote mode
		# If not supported, just skip this testing with a warning
		set_speed_remote ${each}
		if [ $? -ne 0 ]; then
			echo "WARNING: $each mode not supported by remote"
			continue;  
		fi

		echo "Testing $each mode..."

		set_speed ${each}
		if [ $? -ne 0 ]; then
			FAIL_FLAG=1
			echo "ERROR: $each mode can not be enabled."
			continue
		fi

		echo "Running maxq at ${each} ......"
		run_maxq || FAIL_FLAG=1

	else
		echo "WARNING: $each mode not supported."
	fi

done

restore_prop 

support_jumbo ${TST_INT} || exit_test "Jumbo Frame not supported."

#test mtu setting
test_mode=`get_parameter TEST_MTU`
echo "Start testing jumbo frame feature, mtu on $test_mode"

cur_local_mtu=`get_mtu ${TST_INT}${TST_NUM}`
if [ $? -ne 0 ]; then
	echo $cur_local_mtu
	FAIL_FLAG=1
else
	echo Current local mtu is $cur_local_mtu
fi
cur_remote_mtu=$(rsh ${RMT_HST} "dladm show-linkprop -c -o VALUE -p mtu ${RMT_INT}${RMT_NUM}")
if [ -z "$cur_remote_mtu" ]; then
	echo "ERROR: get remote mtu failed"
	FAIL_FLAG=1
else
	echo "Current remote mtu is $cur_remote_mtu"
fi

for each in $test_mode; do
	echo "Testing mtu $each..."
	save_interface  ${TST_INT}${TST_NUM}
	set_mtu ${TST_INT}${TST_NUM} ${each}
	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
		echo "ERROR: set mtu to $each failed."
	fi
	restore_interface ${TST_INT}${TST_NUM}
	sleep 5

	set_mtu_remote ${RMT_HST} ${RMT_INT} ${RMT_NUM} ${each}
	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
		echo "WARNING: set remote mtu to $each failed."
		continue
	fi
	
	typeset snoop_file=/tmp/snoop.$$.${TST_INT}${TST_NUM}
	snoop -d ${TST_INT}${TST_NUM} -o $snoop_file icmp and $LOCAL_HST and $RMT_HST > /dev/null 2>&1 &
	snoop_id=$!

	ping -s $RMT_HST ${each} 3 || fail "Failed to ping remote host when mtu is $each"

	sleep 5	
	kill $snoop_id

	if [ -z "`snoop -i $snoop_file -r greater $each`" ]; then
		fail "No packet larger than $each were captured!"
	fi

	# run ping.auto
	run_ping || FAIL_FLAG=1

	# run ftp test
	run_time=`get_parameter FTP13_RUN_TIME`
	echo ${STF_SUITE}/tools/ftp/${STF_EXECUTE_MODE}/ftp.auto \
	    -r ${RMT_HST} -s 100m -t $run_time -P $TST_PASS \
	    -m "root@localhost" -p $TST_INT -e 0
	${STF_SUITE}/tools/ftp/${STF_EXECUTE_MODE}/ftp.auto \
	    -r ${RMT_HST} -s 100m -t $run_time -P $TST_PASS \
	    -m "root@localhost" -p $TST_INT -e 0  || FAIL_FLAG=1

	# run corrupt
	run_corrupt || FAIL_FLAG=1

	# run maxq
	run_maxq || FAIL_FLAG=1

	#
        # Make sure remote host is alive
        #
        check_host_alive $LOCAL_HST $RMT_HST
        if [ $? -ne 0 ]; then
                fail "The link isn't up after setting to $each mode"
        fi
done

#
# Restore the mtu
#
echo "restore mtu ..."

# Local mtu
save_interface  ${TST_INT}${TST_NUM}
set_mtu ${TST_INT}${TST_NUM} $cur_local_mtu
if [ $? -ne 0 ]; then
        FAIL_FLAG=1
        echo "ERROR: set mtu to $each failed."
fi
restore_interface ${TST_INT}${TST_NUM}

# Remote mtu
set_mtu_remote ${RMT_HST} ${RMT_INT} ${RMT_NUM} $cur_remote_mtu
if [ $? -ne 0 ]; then
        FAIL_FLAG=1
        echo "WARNING: set remote mtu to $each failed."
fi

exit_test "Test finish!"
