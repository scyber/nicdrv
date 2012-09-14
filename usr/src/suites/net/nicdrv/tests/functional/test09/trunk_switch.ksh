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
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)trunk_switch.ksh	1.3	08/04/22 SMI"
#

#
# This script is to add/remove interfaces into/from aggregation
#

AGGR_INT=1
SLEEP_TIME=20

echo "trunk_switch: start"
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
                -a)
                        AGG_INSTANCE=$2
                        export AGG_INSTANCE
                        shift 2
                        ;;
		-l)
			LOCAL_HOST=$2
			export LOCAL_HOST
			shift 2
			;;
		-m)
			LOCAL_NETMASK=$2
			export LOCAL_HOST
			shift 2
			;;
        esac
done

LOCAL_INTERFACE=`echo $LOCAL_INTERFACE|sed 's/,/ /g'`;export LOCAL_INTERFACE

#
# Allow traffic to run 30 secs
#
sleep 30

# 
# Since there is already a interface, add all other interfaces
# in $LOCAL_INTERFACE into aggregation
#
aggr_interface=1
for cur_int in $LOCAL_INTERFACE; do
	dladm show-aggr -L| grep $cur_int
	if [ $? -ne 0 ]; then
		dladm add-aggr -d $cur_int ${AGGR_INT}
		if [ $? -eq 0 ]; then
			aggr_interface=`expr $aggr_interface + 1`
		fi
	else
		base_int=$cur_int
	fi
done

echo "trunk_switch: $aggr_interface in this aggr, switch begins below"

if_netmask=$LOCAL_NETMASK
ifconfig aggr${AGGR_INT} > /dev/null 2>&1
if [ $? -ne 0 ]; then
	ifconfig aggr${AGGR_INT} plumb ${LOCAL_HOST} netmask $if_netmask up
fi
	
#
# Now add/remove interfaces into/from aggregation
#
while true; do
	#
	# Only 1 interface is in aggregation
	#
	if [ $aggr_interface -eq 1 ]; then
		ifconfig aggr${AGGR_INT} unplumb
		dladm delete-aggr $AGGR_INT
		echo "trunk_switch: aggr${AGGR_INT} deleted"
		dladm create-aggr -d $base_int $AGGR_INT
		ifconfig aggr${AGGR_INT} plumb ${LOCAL_HOST} \
			netmask $if_netmask up
		echo "trunk_switch: aggr${AGGR_INT} plumbed"
		sleep ${SLEEP_TIME}
	else
		#
		# Remove loop
		#
		for cur_int in $LOCAL_INTERFACE; do
			if [ "$base_int" != "$cur_int" ]; then
				dladm show-aggr -L| grep $cur_int
				if [ $? -eq 0 ]; then
					dladm remove-aggr -d $cur_int $AGGR_INT
				fi
			fi
		done
		#
		# Add loop
		#
		for cur_int in $LOCAL_INTERFACE; do
			if [ "$base_int" != "$cur_int" ]; then
				dladm show-aggr -L| grep $cur_int 
				if [ $? -ne 0 ]; then
					dladm add-aggr -d $cur_int $AGGR_INT
				fi
			fi
		done
		sleep ${SLEEP_TIME}
	fi
done
