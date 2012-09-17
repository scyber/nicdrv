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
# ident	"@(#)runme.ksh	1.1	09/06/24 SMI"
#

###############################################################################
# __stc_assertion_start
# 
# ID: tests/functional/test14
# 
# DESCRIPTION:
# 	Test IPMI functionality: initialization and data transmit/receive 
# STRATEGY:
#	- Check test machine ipmi feature support.
#	- Get test machine ipmi configuration and hardware information locally.
#	- Run net traffic(udp,tcp,icmp) on nic/vlan interface,at same time verify 
#	    ipmi interface can work smoothly(ping,ipmitool).
#	- Do nic driver load/unload to make sure ipmi sideband connection can 
#	    still works(ping,ipmitool).
#	- Get test machine ipmi configuration remotely,compare with previous
#	- Invoke kstat commands for the IPMI interface,Check overflow and 
#           error for each counter.
#
# TESTABILITY: implicit
# 
# AUTHOR: yuan.fan@Sun.COM
# 
# REVIEWERS:
# 
# TEST AUTOMATION LEVEL: automated
# 
# CODING_STATUS:  COMPLETED (2009-04-15)
# 
# __stc_assertion_end
# 
###############################################################################

# $1 - local host IP
# $2 - remote host IP
# $3 - local driver 
# $4 - local driver instance
# $5 - remote driver
# $6 - remote driver instance
# $7 - maxq run time
# $8 - vlan subnet perfix
# $9 - vlan num
# $10 - ipmi ip
# $11 - ipmi password

. ${STF_TOOLS}/include/stf_common.kshlib
. ${STF_SUITE}/include/common.kshlib

# Define local variables
readonly ME=$(whence -p ${0})
FAIL_FLAG=0
# Extract and print assertion information from this source script to journal
extract_assertion_info $ME

dtrace_start "14" ${TST_INT}
dtr_pid=$(echo $!)

RUN_TIME=$(get_parameter IPMI_RUN_TIME)
VLAN_NUM=$(get_parameter VLAN_NUM)
VLAN_SUBNET=$(get_parameter VLAN_SUBNET)

#
# Function check_ipmi_support
# verify host machine support IPMI,can configuration correct
#
check_ipmi_support()
{
	echo $LOCAL_IPMI_PASS > /tmp/password
	ipmitool -I lan -U $LOCAL_IPMI_USER -f /tmp/password -H $LOCAL_IPMI_IP lan print > /tmp/ipmi.local
	if (( $? != 0 )); then
		echo "Your host machine does't support IPMI feature"
		exit $STF_UNSUPPORTED
	fi
	ping ${LOCAL_IPMI_IP} > /dev/null 2>&1
	if [[ $? != 0 ]]; then
		exit $STF_UNSUPPORTED	
        fi
	return 0
}

check_ipmi_support

${STF_SUITE}/${STF_EXEC}/ipmi.auto \
	${LOCAL_HST} ${RMT_HST} ${TST_INT} ${TST_NUM} \
	${RMT_INT} ${RMT_NUM} ${RUN_TIME} ${VLAN_SUBNET} \
	${VLAN_NUM} ${LOCAL_IPMI_IP} ${LOCAL_IPMI_PASS} ${LOCAL_IPMI_USER}

if [ $? -ne 0 ]; then
	echo "$cmd Failed : result = $?"
	FAIL_FLAG=1
fi

dtrace_end $dtr_pid "14"
if [ $FAIL_FLAG -ne 0 ]; then
	exit ${STF_FAIL}
else	
	exit ${STF_PASS}
fi
