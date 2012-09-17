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
# ident	"@(#)Nemo_Trunk.auto.ksh	1.6	09/06/24 SMI"
#

. ${STF_TOOLS}/include/stf_common.kshlib
. ${STF_SUITE}/include/common.kshlib
usage()
{
	echo "\nUsage: `basename $0` --help | \
		-i <list_interfaces> -c <remote_ip> -l <local_ip>"
	echo "  Options:"
	echo "		--help:		Help information"
	echo "		-i:		List of interfaces locally in test"
	echo "	Example:"
	echo "		./Nemo_Trunk.auto --help"
	echo "		./Nemo_Trunk.auto -i e1000g0,e1000g1,e1000g2 \
		-c 11.0.1.2 -l 11.0.1.1"
}

#
# Usage: Nemo_trunk.auto -i <list_interfaces> -c <remote_ip> -l <local_ip>
#

AGGR_INST=1
TEST_TIME=`get_parameter test09_RUN_TIME`

cur_pid=`echo $$`
FAIL_FLAG=0

#
# $1 is the list of local interfaces paticipant into the test
#
clean_aggr()
{
        ifconfig aggr${AGGR_INST} > /dev/null 2>&1
        if [ $? -eq 0 ]; then
                ifconfig aggr1 unplumb
	fi

	dladm show-aggr $AGGR_INST
	if [ $? -eq 0 ]; then
		dladm delete-aggr $AGGR_INST
		if [ $? -ne 0 ]; then
			echo "clean_aggr: delete-aggr failed!"
			return
		fi
	fi
	first_int=`echo $1 | awk '{print $1}'`
	if [ ! -z $OLD_INET_IP ]; then
		ifconfig $first_int plumb $OLD_INET_IP netmask $if_netmask up
	fi
}

show_aggr()
{
		echo "ifconfig -a"
		ifconfig -a
                echo "dladm show-aggr -L"
                dladm show-aggr -L
}

test_fail()
{
		echo "ERROR: $1"
		show_aggr
		clean_aggr $LOCAL_INTERFACE
		exit 1
}

CURDIR=`pwd`
TESTNAME=`basename $0`
SOURCEFILE=$CURDIR/${TESTNAME}rc

trap "pkill Corrupt.auto; clean_aggr $LOCAL_INTERFACE; exit 1" 1 2 3 9 15

#
# Check if current system support Nemo trunking
#    if not, return
#
if [ ! -f "/usr/sbin/dladm" ]; then
	echo "ERROR: OS version does not support dladm"
	exit 0
fi

#
# Source the rc file if it exists
#

if [ -f $SOURCEFILE ]; then
	. $SOURCEFILE
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
		-l)
			LOCAL_HOST=$2
			export LOCAL_HOST
			shift 2
			;;
		--help) usage
			exit 0
			;;
	esac
done

#
# Filter the interfaces list clear of ,
#
OLD_INTERFACE=$LOCAL_INTERFACE
LOCAL_INTERFACE=`echo $LOCAL_INTERFACE|sed 's/,/ /g'`;export LOCAL_INTERFACE

show_aggr

#
# Before go further, make sure all of the interfaces in trunk test are not
# busy. The first interface's IP is to be used as trunk IP
#
tst_int=`netstat -rn|grep $LOCAL_HOST|awk '{print $6}'|head -1`
if [ -z $tst_int ]; then
	if_netmask="0xffffff00"
else
	if_netmask=0x`ifconfig $tst_int | grep inet|awk '{print $4}'`
fi

OLD_INET_IP=
int_cnt=0
for cur_int in $LOCAL_INTERFACE; do
	ip=`ifconfig $cur_int | grep inet | awk '{print $2}'`
	if [ $? -eq 0 ]; then
		OLD_INET_IP=$ip
		ifconfig $cur_int dhcp drop 2>/dev/null
		ifconfig $cur_int unplumb
	fi
	int_cnt=`expr $int_cnt + 1`
	if [ $int_cnt -eq 1 ]; then
		if [ $LOCAL_HOST = "" ]; then
			aggr_ip=$ip
		else
			aggr_ip=$LOCAL_HOST
		fi
	fi
done

#
# Add interfaces into aggregations in a loop
#    In each loop, do the following:
#    (1) Run NFS_Corrupt.auto
#    (2) Show the aggregation to see if there are correct number
#	 of interfaces
#
aggr_cnt=0
#
#
for cur_int in $LOCAL_INTERFACE; do
	if [ $aggr_cnt -eq 0 ]; then
		ifconfig aggr${AGGR_INST} > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			test_fail "aggr${AGGR_INST} already exists, unplumb and delete it"
		else
			base_int=$cur_int
			dladm create-aggr -d $cur_int  ${AGGR_INST}
			if [ $? -ne 0 ]; then
				test_fail "error of dladm create-aggr for $cur_int"
			fi
			ifconfig aggr${AGGR_INST} plumb $aggr_ip \
				netmask $if_netmask up

		fi
	else
		dladm add-aggr -d $cur_int ${AGGR_INST}
		if [ $? -ne 0 ]; then
			test_fail "dladm add-aggr for $cur_int"
		fi
	fi

	aggr_cnt=`expr $aggr_cnt + 1`

	# double check the aggregation contains cur_int information
	dladm show-aggr -L |grep " $cur_int " > /dev/null	
	if [ $? -ne 0 ]; then
		echo "WARNING: can't find interface $cur_int in aggregation!"
	fi

	# Show current aggregation
	echo "aggregation created."
	show_aggr

	#
	# Make sure the link is up
	#
	check_host_alive $LOCAL_HOST $REMOTE_HOST
	if [ $? -ne 0 ]; then
		test_fail "The link isn't up"
	fi

	#
	# Run NFS traffic (tcp/udp) over current aggregation
	#
	${STF_SUITE}/tools/nfscorrupt/${STF_EXECUTE_MODE}/Corrupt.auto \
		-c $REMOTE_HOST -s $aggr_ip -n 1 -t ${TEST_TIME} \
		-e "root@localhost" -p "nicdrv" -m tcp -r no -d bi
	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
	fi


	${STF_SUITE}/tools/nfscorrupt/${STF_EXECUTE_MODE}/Corrupt.auto \
		-c $REMOTE_HOST -s $aggr_ip -n 1 -t ${TEST_TIME} \
		-e "root@localhost" -p "nicdrv" -m udp -r no -d bi
	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
	fi


done

# 
# 4. Remove interfaces from aggregations in a loop
#    (1) Show the aggregation to see if there are correct number
#        of interfaces
#   
for cur_int in $LOCAL_INTERFACE; do
	if [ $aggr_cnt -gt 1 ]; then
		dladm remove-aggr -d $cur_int ${AGGR_INST}
	        if [ $? -ne 0 ]; then
			test_fail "can't remove interface $cur_int from aggregation!"
		fi
	else
		ifconfig aggr${AGGR_INST} unplumb
		dladm delete-aggr $AGGR_INST
		if [ $? -ne 0 ]; then
			test_fail "can't delete aggregation"
		else
			break
		fi
	fi
	
done

echo "--- Nemo_trunk: Basic Test Done ---"
echo " "
sleep 25

#
# 5. Advanced test
#    If selected from RC file or command line
#    (1) Run nfscorrupt test over the aggregation
#    (2) Add/remove the interfaces into/from aggregation while traffic running
#    (3) exit after 4 hrs test
#

#
# Before start network test, create an aggr
#
dladm create-aggr -d $base_int $AGGR_INST
ifconfig aggr${AGGR_INST} plumb ${LOCAL_HOST} netmask $if_netmask up
while true; do
	ping ${REMOTE_HOST} > /dev/null
	if [ $? -eq 0 ]; then
		break
	fi
done

#
# Start the switch aggregation in background
#
pkill -P $cur_pid trunk
${STF_SUITE}/${STF_EXEC}/trunk_switch \
	-i $OLD_INTERFACE -a 1 -c $REMOTE_HOST -l $LOCAL_HOST -m $if_netmask &
switch_pid=`echo $!`

#
# Run ftp traffic over current aggregation
#
${STF_SUITE}/tools/nfscorrupt/${STF_EXECUTE_MODE}/Corrupt.auto \
	-c $REMOTE_HOST -s $aggr_ip -n 1 -t ${TEST_TIME} \
	-e "root@localhost" -p "nicdrv" -m udp -r no -d bi
if [ $? -ne 0 ]; then
	FAIL_FLAG=1
fi

# 
# Kill trunk_switch after network traffic(NFS) finished
#
kill $switch_pid
clean_aggr $LOCAL_INTERFACE
echo "aggregation cleaned up."
show_aggr

if [ $FAIL_FLAG -ne 0 ]; then
        echo  "TRUNKING test failed!"
        exit 1
fi

exit 0
echo "TRUNKING test pass!"
