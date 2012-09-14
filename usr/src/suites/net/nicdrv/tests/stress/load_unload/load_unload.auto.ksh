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
# ident	"@(#)load_unload.auto.ksh	1.5	09/06/24 SMI"
#

. ${STF_TOOLS}/include/stf.kshlib
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
	echo "usage: # $0 LocalName RemoteName driver-name \
		local_interface device-id"
	echo " # $0 11.0.1.9 11.0.1.18 e1000g 0 '"pci8086,1010"'"
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

load_unload() 
{
	# Save test interface netmask
	if_netmask=0x`ifconfig $g_drv$g_Local_Interface | \
	    grep inet | awk '{print $4}'`

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


	#
	# do load_unload testing
	#
	iCnt=0
	echo "***Load/Unload Begins, Total $MAX_UNLOAD_TIMES times***"
	while [ $iCnt -lt $MAX_UNLOAD_TIMES ]; do
		echo "-------------------------------------"
		echo "Now iteration $iCnt"
		echo "-------------------------------------"
	
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
		
		ifconfig -a | grep $g_drv
		if [ $? -ne 0 ]; then
			rem_drv $g_drv
			cat /etc/driver_aliases | grep -w $g_drv > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "driver $g_drv does not \
					remove from /etc/driver_aliases"
				break
			fi
			if [ $iCnt -eq 0 ]; then
				dtrace_start "98" ${TST_INT}
				dtr_pid=`echo $!`
			fi
			add_drv -i "$add_dev_list" $g_drv
                	cat /etc/driver_aliases | grep -w $g_drv > /dev/null 2>&1
                	if [ $? -eq 0 ]; then
                        	echo "$g_drv($g_Device_Id) rem/add successfully"
                	fi
		fi

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

		ifconfig $g_drv$g_Local_Interface $g_LocalHost \
			netmask $if_netmask up
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

		# MAXQ now for load_unload can run simul on server and client
		echo "Run MAXQ benchmark over the link"
		cur_port=9090
		for init_data_len in 65000 1460 1; do
			${STF_SUITE}/${STF_EXEC}/plumb_unplumb \
				$g_drv $g_Local_Interface $g_LocalHost \
				$if_netmask $g_RmHost &
			plu_id=`echo $!`
			echo "plumb_unplumb daemon $plu_id started"
			echo "MAXQ payload: $init_data_len starts!"

			${STF_SUITE}/tools/maxq/${STF_EXECUTE_MODE}/MAXQ.auto \
				-s $g_LocalHost -c $g_RmHost -C $g_RmHost \
				-d $init_data_len -b 65535 -M $subnet_ip \
				-m root@localhost -p nicdrv -i 1 -e $linkspeed \
				-T 180 -t 0 -tr bi -S 5 -P TCP_STREAM \
				> /dev/null 2>&1

			kill -9 $plu_id > /dev/null 2>&1
			wait $plu_id
			echo "plumb_unplumb killed"
		done
		echo "MAXQ benchmark done!"
		
		if [ $iCnt -eq 0 ]; then
			dtrace_end $dtr_pid "98"
		fi

		iCnt=`expr $iCnt + 1`
		echo "driver $g_drv load/unload pass $iCnt times"
	done

	echo "---test load/unload for $MAX_UNLOAD_TIMES times---"

	#
	# Restore the test environment, plumb all interface
	#
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
		echo "Test failed due to can't recover interfaces"
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

if [ $# -ne 4 ]
then
	usage
	exit 1
fi

g_LocalHost=$1
g_RmHost=$2
g_drv=$3
g_Local_Interface=$4

device_id_list=`cat /etc/driver_aliases | grep -w $g_drv \
    | awk '{print $2}' | sed 's/"//g'`
for device_id in $device_id_list; do
	pci_output=`prtconf -vp | grep $device_id`
	if [ $? -eq 0 ]; then
		echo "Get a possible device id for driver $g_drv: $device_id"
		g_Device_Id="\"$device_id\""
		if [ -z "$add_dev_list" ]; then
			add_dev_list=$g_Device_Id
		else
			add_dev_list="$add_dev_list $g_Device_Id"
                fi 
	fi
done 

if [ -z "$add_dev_list" ]; then
	echo "Can't get device id for driver $g_drv"
	exit 1
fi 

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
