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
# ident	"@(#)genreport.ksh	1.2	08/04/22 SMI"
#

. ${STF_TOOLS}/include/stf.kshlib
. ${STF_SUITE}/include/common.kshlib

if [ $DTRACE_SWITCH = "yes" ]; then
	dtrace -l -n ${TST_INT}::entry | \
	    awk '{print $4}' > /tmp/driver_all_func.tmp.log
	echo "=========================================================="
	echo "============== Code Coverage Summary ===================="
	echo "=========================================================="
	cat /tmp/drv_called_func_num_* >> /tmp/sum_called_func.tmp.log
	${STF_SUITE}/tools/summary/dt_clean
	cat /tmp/drv_called_func_num.tmp.log
	echo "----------------------------------------------------------"
	${STF_SUITE}/tools/summary/dt_parse \
	    /tmp/drv_called_func_num.tmp.log
        rm -f /tmp/drv_called_func_*.log
        rm -f /tmp/sum_called_func.tmp.log
	rm -f /tmp/driver_all_func.tmp.log
	rm -f /tmp/driver_called_func.tmp.log 
fi

echo "=========================================================="
echo "==================== Test Summary ========================"
echo "=========================================================="

print_test_env

test_summary

exit 0
