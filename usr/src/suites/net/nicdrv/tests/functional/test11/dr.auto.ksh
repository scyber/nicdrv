#!/usr/bin/ksh -p
#
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)dr.auto.ksh	1.2	09/03/04 SMI"
#

. ${STF_TOOLS}/include/stf_common.kshlib

g_LocalHost=$1
g_RmHost=$2
g_Local_Interface=$3

AP_ID=""
RUN_TIME=$5

if [ -z "$RUN_TIME" ]; then
	RUN_TIME=1
fi

SUPPORT_UNCONFIGURE=false
SUPPORT_DISCONNECT=false


usage()
{
        echo "dr.auto v1.0 12/11/07"
        echo "Failed: bad parameters ! dr.auto need at least 3 paramaters !"
        echo "usage: # $0 LocalHost RemoteHost local_interface [run_times]"
        echo " # $0 11.0.0.1 11.0.0.2 e1000g0 10"
}

# use cfgadm command to configure and unconfigure 
# the attachment ponit for 10 times
# $1 is the attachment point ID
test_fail()
{
	echo "ERROR: $1"
	echo "cfgadm"
	cfgadm
	echo "ifconfig -a"
	ifconfig -a
	if [ -n "$AP_ID" ]; then
		echo "cfgadm -f -c connect $AP_ID"
		cfgadm -f -c connect $AP_ID
		echo "cfgadm -c configure $AP_ID"
		cfgadm -c configure $AP_ID
	fi
	plumb_interface
	exit $STF_FAIL
}

do_cfgadm_test()
{
	count=0
	ap_id=$1
	if [ -z "$ap_id" ]; then
		return $STF_UNRESOLVED
	fi
	unplumb_interface 

	cfgadm -c unconfigure $ap_id
	if [ $? -eq 0 ]; then
		echo "$ap_id support cfgadm -c unconfigure command"
		SUPPORT_UNCONFIGURE=true
	fi

	cfgadm -f -c disconnect $ap_id
	if [ $? -eq 0 ]; then
		echo "$ap_id support cfgadm -f -c disconnect command"
		SUPPORT_DISCONNECT=true
	fi
	
	if [ "$SUPPORT_UNCONFIGURE" = "false" ] &&  [ "$SUPPORT_DISCONNECT" = "false" ]; then
		test_fail "$ap_id doesn't support dynamic reconfiguration"
	fi


	while [ $count -lt $RUN_TIME ] ; do


		if [ "$SUPPORT_DISCONNECT" = "true" ]; then
			cfgadm -c connect $ap_id
			if [ $? -ne 0 ]; then
				test_fail "cfgadm -c connect $ap_id failed" 
			fi
		fi

		if [ "$SUPPORT_UNCONFIGURE" = "true" ]; then
			cfgadm -c configure $ap_id
			if [ $? -ne 0 ]; then
				test_fail "cfgadm -c unconfigure $ap_id failed"
			fi
		fi

		sleep 1

		plumb_interface 

                #
                # doing some traffic after plumb
                #
                echo "Traffic Over Link Begins "
                echo "ping $g_RmHost with 10 packets, payload 1472"
                ping -s $g_RmHost 1472 10 > /dev/null 2>&1

                if [ $? -ne 0 ]; then
                        test_fail "ping fail over test interfaces"
                else
                        echo "ping 10 packets sucess"
                fi

		unplumb_interface

		if [ "$SUPPORT_UNCONFIGURE" = "true" ]; then
			cfgadm -c unconfigure $ap_id
			if [ $? -ne 0 ]; then
				test_fail "cfgadm -c unconfigure $ap_id failed"
			fi
		fi

		if [ "$SUPPORT_DISCONNECT" = "true" ]; then
			cfgadm -f -c disconnect $ap_id
			if [ $? -ne 0 ]; then
				test_fail "cfgadm -c disconnect $ap_id failed"
			fi
		fi

		count=`expr $count + 1`
	done

	if [ "$SUPPORT_DISCONNECT" = "true" ]; then
		cfgadm -f -c connect $ap_id
		if [ $? -ne 0 ]; then
			test_fail "cfgadm -c connect $ap_id failed"
		fi
	fi

	if [ "$SUPPORT_UNCONFIGURE" = "true" ]; then
		cfgadm -c configure $ap_id
		if [ $? -ne 0 ]; then
			test_fail "cfgadm -c unconfigure $ap_id failed"
		fi
	fi

	plumb_interface
	ifconfig -a
	return $STF_PASS

}


# Find all network interface for a given attachment point
# save configurations for each interface and then unplumb it
# $1 the ID of the attachement ponit

save_ap_interface()
{
	ap_id=$1
        if [ -z "$ap_id" ]; then
                return 1
        fi

#	ALL_INTERFACE=`cfgadm -c unconfigure $ap_id 2>&1|grep SUNW_network |awk '{print $2}'`
	
	ap_path=`cfgadm -v $ap_id |awk '/devices/ {print $NF}' |awk -F: '{print $1}'`
	ALL_INTERFACE=`ls -l $ap_path |grep ^c |awk -F: '{print $NF}'`

        for each_int in $ALL_INTERFACE; do
                eval IP_${each_int}=`ifconfig ${each_int} | \
                    grep inet | awk '{print $2}'`
                eval NETMASK_${each_int}=0x`ifconfig ${each_int} | \
                    grep netmask | awk -F' ' '{print $4}'`
                eval DHCP_${each_int}=`ifconfig ${each_int}  | \
                    grep DHCP | wc -l | awk '{print $1}'`
        done

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

# unplumb all interface whose name is stored in $ALL_INTERFACE
# and all setting is stored in $IP_*, $NETMASK_*, $DHCP_*
# save_ap_interface must be run to set these variables
#
unplumb_interface()
{
	for each_int in $ALL_INTERFACE; do
		eval each_ip=\$IP_${each_int}
		eval each_mask=\$NETMASK_${each_int}
		eval each_dhcp=\$DHCP_${each_int}
		if [ $each_dhcp -eq 0 ]; then
			int_unplumb ${each_int} ${each_ip} ${each_mask}
		else
			int_unplumb_dhcp ${each_int}
		fi
	done
}

#  plumb all interface whose name is stored in $ALL_INTERFACE
# and all setting is stored in $IP_*, $NETMASK_*, $DHCP_*
# save_ap_interface must be run to set these variables
#
plumb_interface()
{
        for each_int in $ALL_INTERFACE; do
                eval each_ip=\$IP_${each_int}
                eval each_mask=\$NETMASK_${each_int}
                eval each_dhcp=\$DHCP_${each_int}
		ifconfig $each_int > /dev/null 2>&1
		
                if [ $each_dhcp -eq 0 ]; then
                        int_plumb ${each_int} ${each_ip} ${each_mask}
                else
                        int_plumb_dhcp ${each_int}
                fi
        done

}

find_ap_id()
{
        device=$1
        # make sure the device is currently plumbed, so that cfgadm unconfigure will fail for this device
        ifconfig $device
        if [ $? -eq 1 ]; then
                ifconfig $device plumb
        fi

	# get all configured attachment ponit id 
        all_ap=`cfgadm |grep " configured" |awk '{print $1}'`

        for ap in $all_ap; do
		# get the device path for an attachment ponit
		ap_path=`cfgadm -v $ap |awk '/devices/ {print $NF}' |awk -F: '{print $1}'`
		if [ -z "$ap_path" ]; then
			continue
		else
			# if we can find $device under attachment ponit directory, the ap is what we want to find 
			ls $ap_path |grep $device > /dev/null 2>&1
			if [  $? -eq 0 ]; then
				echo "Found ap id for device $device: $ap."
				AP_ID=$ap
				break
			fi
		fi
        done
	if [ -z "$AP_ID" ]; then
		return 1
	fi
	return 0
}


#
# main
#
for i in $*; do
        case $1 in
                --help) usage
                        exit $STF_UNRESOLVED
                        ;;
        esac
done

if [ $# -lt 3 ]
then
        usage
	exit $STF_UNRESOLVED
fi

ifconfig $g_Local_Interface > /dev/null 2>&1

if [ $? -ne 0 ]; then
	echo "please enter a valid network interface name"
	exit $STF_UNRESOLVED
fi
find_ap_id $g_Local_Interface

if [ $? -ne 0 ]; then
	echo "can't find attachement ponit for the network interface"
	cfgadm
	exit $STF_UNSUPPORTED
fi

save_ap_interface $AP_ID

do_cfgadm_test $AP_ID

