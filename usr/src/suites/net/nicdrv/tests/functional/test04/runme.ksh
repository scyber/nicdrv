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
# ident	"@(#)runme.ksh	1.2	08/04/22 SMI"
#

###############################################################################
# __stc_assertion_start
# 
# ID: tests/functional/test04
# 
# DESCRIPTION:
#         Test MULTICAST functionality
# 
# STRATEGY:
#         - Add multicast route and join multicast group
#         - Receive ip_multicast traffic from the client side
#           with 1 multicast group.
#         - Send ip_multicast traffic to the client side
#           with 1 multicast group.
#         - Join multiple multicast groups, and receive multicast
#           traffic of multiple groups from the client.
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

RUN_TIME=`get_parameter MCAST_RUN_TIME`

dtrace_start "04" ${TST_INT}
dtr_pid=`echo $!`

${STF_SUITE}/tools/multicast/${STF_EXECUTE_MODE}/mcast.auto \
	-c ${RMT_HST} -cg ${RMT_HST} -ci ${RMT_INT}${RMT_NUM} \
	-s ${LOCAL_HST} -sg ${LOCAL_HST} -si ${TST_INT}${TST_NUM} \
	-r 1 -t $RUN_TIME -m 225.0.0.1 -g ${MAX_MULTICAST_GRP}

if [ $? -ne 0 ]; then
	dtrace_end $dtr_pid "04"
	exit ${STF_FAIL}
else
	dtrace_end $dtr_pid "04"
	exit ${STF_PASS}
fi

