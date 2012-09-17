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
# ident	"@(#)load_unload.auto.ksh	1.1	09/06/24 SMI"
#

. ${STF_TOOLS}/include/stf_common.kshlib
. ${STF_SUITE}/include/common.kshlib

integer debug=0
integer FAIL_FLAG=0
integer MAX_UNLOAD_TIMES=20
integer UNLOAD_TIMES_TRAFFIC=100
typeset g_LocalHost="" # "Local Host Name"
typeset g_RmHost="" # "Remote Host Name"
typeset g_drv="" # driver name (eg bge | ce)
typeset g_Local_Interface="" # driver interface to connect RmHost
typeset g_Device_Id="" # device is for drv

usage()
{
	echo "load_unload.auto v1.0 05/11/01"
	echo "Failed: bad parameters ! load_unload.auto need 5 paramaters !"
	echo "usage: # $0 LocalName RemoteName driver-name local_interface device-id run_times"
	echo " # $0 11.0.1.9 11.0.1.18 e1000g 0 '"pci8086,1010"' 10"
}

int_plumb_dhcp()
{
        echo "plumb $1 with DHCP"
	ifconfig $1 plumb
	ifconfig $1 dhcp
	ifconfig $1 up
}

int_unplumb_dhcp()
{
        echo "unplumb $1 with DHCP"
	ifconfig $1 dhcp drop
	ifconfig $1 unplumb
}

int_plumb()
{
        echo "plumb $1 with ip $2 and netmask $3"
	ifconfig $1 plumb $2 netmask $3 up 
}

int_unplumb()
{
        echo "unplumb $1 with ip $2 and netmask $3"
	ifconfig $1 unplumb
}


save_interface()
{
	# Save current machine's interfaces related to the test interface
	int_list=`ifconfig -a | grep $g_drv | awk -F: '{print $1}'`
	for each_int in $int_list; do
		eval ip${each_int}=`ifconfig ${each_int} | \
		    grep inet | awk '{print $2}'`
		eval mask${each_int}=0x`ifconfig ${each_int} | \
		    grep netmask | awk -F' ' '{print $4}'`
		eval dhcp${each_int}=`ifconfig ${each_int}  | \
		    grep DHCP | wc -l | awk '{print $1}'`
	done


}

unplumb_all_interface()
{
                #
                # unplumb current machine's interfaces with the Driver
                #
                for each_int in $int_list; do
                        eval each_ip=\$ip${each_int}
                        eval each_mask=\$mask${each_int}
                        eval each_dhcp=\$dhcp${each_int}
                        if [ $each_dhcp -eq 0 ]; then
                                int_unplumb ${each_int} ${each_ip} ${each_mask}
                        else
                                int_unplumb_dhcp ${each_int}
                        fi
                done

                echo "All interfaces unplumbed"

}

plumb_all_interface()
{
		for each_int in $int_list; do
			eval each_ip=\$ip${each_int}
			eval each_mask=\$mask${each_int}
			eval each_dhcp=\$dhcp${each_int}
			if [ $each_dhcp -eq 0 ]; then
				int_plumb ${each_int} ${each_ip} ${each_mask}
			else
				int_plumb_dhcp ${each_int}
			fi
		done

		echo "All interfaces plumbed"
}

cleanup()
{
	echo "Clean up, try to restore test interface."
	add_driver 
	plumb_all_interface	
	exit 1
}

add_driver()
{
	typeset result=0

	add_drv $g_drv
	result=$?
	
	for id in $add_dev_list
	do
		update_drv -a -i "$id" $g_drv		
		if [ $? -ne 0 ]; then
			result=$?
		fi
	done
	return $result
}

load_unload()
{
	typeset tmp_result=0
	# Save test interface netmask
	if_netmask=0x`ifconfig $g_drv$g_Local_Interface | \
	    grep inet | awk '{print $4}'`

	save_interface

	# get maximum kernel memory size allowed for driver
	max_mem_size=$(get_parameter test10_MAX_MEMORY)

	#
	# do load_unload testing
	#
	iCnt=0
	echo "***Load/Unload Begins, Total $MAX_UNLOAD_TIMES times***"
	while [ $iCnt -lt $MAX_UNLOAD_TIMES ]; do
		echo "-------------------------------------"
		echo "Now iteration $iCnt"
		echo "-------------------------------------"
	
		unplumb_all_interface

		ifconfig -a | grep $g_drv
		if [ $? -eq 0 ]; then
			echo "Error: Not all interface unplumbed."
			plumb_all_interface
			exit 1
		fi

		# an extra check for e1000g, because mblk hold by uplayer
		if [ "$g_drv" = "e1000g" ]; then
			typeset -i sleep_cnt=1
			# Should set a limit for sleep_cnt later. lt
			while true; do
				tmp_result=`echo "e1000g_mblks_pending/X" | \
					mdb -k | awk '{print $2}'`
				if [ $tmp_result -eq 0 ]; then
					echo "mblk of e1000g free" 
					break
				else
					echo "e1000g_mblks_pending=$tmp_result sleep $sleep_cnt"
					sleep $sleep_cnt
					sleep_cnt=$((sleep_cnt * 2))
				fi
			done
		fi

		rem_drv $g_drv
		if [ "$?" -ne 0 ]; then
			FAIL_FLAG=1
			echo "rem_drv $g_drv FAIL"
		fi

		cat /etc/driver_aliases | grep -w $g_drv > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "Warning: driver $g_drv is still in /etc/driver_aliases"
		fi
		
		add_driver 
		if [ "$?" -ne 0 ]; then
			FAIL_FLAG=1
			echo "add_drv -i $add_dev_list $g_drv FAIL"
		fi
		cat /etc/driver_aliases | grep -w $g_drv > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "$g_drv($g_Device_Id) driver add successfully"
		else
			echo "Can not find driver in driver_aliases , Test FAIL!"
			exit 1
		fi
	
		plumb_all_interface

		ifconfig $g_drv$g_Local_Interface 
		if [ $? -ne 0 ]; then
			echo "Failed to plumb up test interface!"
			exit 1
		fi
		mac_old=`ifconfig $g_drv$g_Local_Interface | \
			grep ether | awk '{print $2}'`
		mac_new="0:1:2:3:4:5"	
		ifconfig $g_drv$g_Local_Interface ether $mac_new
		mac_check=`ifconfig $g_drv$g_Local_Interface | \
			grep ether | awk '{print $2}'`
		if [ $mac_new = $mac_check ]; then
			echo "MAC change successfully"
		else
			echo "MAC change failed"
		fi
		
		ifconfig $g_drv$g_Local_Interface ether $mac_old
		modinfo  |  grep -w $g_drv
		if [ $? -ne 0 ]; then
			echo "modinfo could not retrive driver info"
			exit 1
		fi
		ifconfig -a	

		linkspeed=0
		until [ "$linkspeed" != "0" ]; do
                	linkspeed=`get_linkspeed ${TST_INT} ${TST_NUM}`
			if [ "$linkspeed" != "0" ];then
				sleep 1
				subnet_ip=`get_subnetip ${TST_INT} ${TST_NUM}`
				if [ "$subnet_ip" = "0" ]; then
					echo "can't not get subnet_ip"
        				exit 1
				fi
				break
			fi
			sleep 1
		done
		echo "${TST_INT}${TST_NUM} link up after config"

		#
		# doing some traffic after plumb
		#
		echo "Traffic Over Link Begins "
		echo "ping $g_RmHost with 10 packets, payload 1472"
		ping -s $g_RmHost 1472 10 > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo "ping fail over test interfaces"
		else
			echo "ping 10 packets sucess"
		fi
		iCnt=`expr $iCnt + 1`
		echo "driver $g_drv load/unload pass $iCnt times"
	done

	echo "---test load/unload for $MAX_UNLOAD_TIMES times---"

	for each_int in $int_list; do
		eval each_dhcp=\$dhcp${each_int}
       		ifconfig $each_int > /dev/null 2>&1
        	if [ $? -ne 0 ]; then
			if [ $each_dhcp -eq 0 ]; then
                		echo "Interface $each_int recover failed"
				FAIL_FLAG=1
			else
				echo "DHCP interface $each_int recover failed"
				echo "It might be a DCHP issue..."
			fi
        	fi
	done

	# Get all interface after test finished
	ifconfig -a
	if [ $FAIL_FLAG -ne 0 ]; then
		#echo "Test failed due to can't recover interfaces"
		exit 1
	fi

	echo "All interfaces were recovered"

}


#
# main
#
for i in $*; do
	case $1 in
		--help) usage
			exit 0
			;;
	esac
done

if [ $# -ne 5 ]
then
	usage
	exit 1
fi

g_LocalHost=$1
g_RmHost=$2
g_drv=$3
g_Local_Interface=$4
MAX_UNLOAD_TIMES=$5

add_dev_list=`cat /etc/driver_aliases | grep -w $g_drv \
    | awk '{ORS=" "; print $2}'`

if [ -z "$add_dev_list" ]; then
	echo "Can't get device id for driver $g_drv"
	exit 1
fi 

trap "cleanup"  1 2 3 5 15

load_unload


#
# Check the client's state after stress test.
#
check_host_alive $g_LocalHost $g_RmHost
if [ $? -ne 0 ]; then
        echo "The client isn't alive, Test FAIL!"
        exit 1
else
        echo "The client is alive, PASS!"
fi

#
# End
#
exit 0
