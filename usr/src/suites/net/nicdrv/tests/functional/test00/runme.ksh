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
# ident	"@(#)runme.ksh	1.4	08/11/12 SMI"
#

###############################################################################
# __stc_assertion_start
# 
# ID: tests/functional/test00
# 
# DESCRIPTION:
#         Test data transmit/receive functionality
# 
# STRATEGY:
#         - Plumb IPv4/IPv6 test interfaces on both client/server.
#         - Repeatedly FTP (get/put) files of different sizes (1/10M/100M/1000M).
#         - For each file size, the ftp traffic should be sustained for at least 900 sec.
#         - All FTP sessions should pass without any errors
# 
# TESTABILITY: statistical and implicit
# 
# AUTHOR: Oliver.Yang@Sun.COM
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

setup()
{
	ifconfig ${TST_INT}${TST_NUM} inet6 plumb up
	if [ $? -ne 0 ]; then
		echo "Could not plumb local inet6 interface"
		return 1
	fi
	rsh -l root ${RMT_HST} ifconfig ${RMT_INT}${RMT_NUM} inet6 plumb up
	if [ $? -ne 0 ]; then
		echo "Could not plumb remote inet6 interface"
		return 1
	else
		rmt_inet6_hst=`rsh -l root ${RMT_HST} \
		    ifconfig ${RMT_INT}${RMT_NUM} inet6 \
		    | grep inet6 | sed 's/\// /g'|awk '{print $2}'`

               	#
               	# Make sure remote host is alive
               	#
               	retry_cnt=0
               	while true; do
                       	if [ $retry_cnt -gt 50 ]; then
				echo "Can't reach the remote ipv6 interface."
				return 1
                       	fi

                       	ping -i ${TST_INT}${TST_NUM} $rmt_inet6_hst >/dev/null 2>&1
                       	if [ $? -eq 0 ]; then
                          	break;
                       	fi
                       	sleep 1
                       	retry_cnt=`expr $retry_cnt + 1`
                done
	fi
	return 0
}

cleanup()
{
	ifconfig ${TST_INT}${TST_NUM} inet6 unplumb
	rsh -l root ${RMT_HST} \
	    ifconfig ${RMT_INT}${RMT_NUM} inet6 unplumb


}

trap "cleanup; exit" 1 2 3 9 15

#
# FTP for IPv6 test
#
do_ipv6_test()
{
	setup
	if [ $? -ne 0 ]; then
        	cleanup
        	FAIL_FLAG=1
	else
        	for file_size in $size_list; do

                	${STF_SUITE}/tools/ftp/${STF_EXECUTE_MODE}/ftp.auto -r $rmt_inet6_hst \
                    	-s $file_size -p nicdrv -t $RUN_TIME -e 1 -P ${TST_PASS}

                	if [ $? -ne 0 ]; then
                        	FAIL_FLAG=1
                	fi

        	done
	fi

	cleanup
}

#
# Main
#
check_host_alive $LOCAL_HST $RMT_HST
if [ $? -ne 0 ]; then
        echo "The client isn't alive!"
        exit ${STF_UNRESOLVED}
fi

#
# Run each file size for 900 seconds
#

size_list=`get_parameter FTP_FILE_SIZE`
RUN_TIME=`get_parameter FTP_RUN_TIME`

dtrace_start "00" ${TST_INT}
dtr_pid=`echo $!`

FAIL_FLAG=0
for file_size in $size_list; do

	${STF_SUITE}/tools/ftp/${STF_EXECUTE_MODE}/ftp.auto -r ${RMT_HST} -s $file_size \
	    -p nicdrv -t $RUN_TIME -e 1 -P ${TST_PASS}

	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
	fi
done

#
# Now IPv6 run
#
do_ipv6_test

dtrace_end $dtr_pid "00"

if [ $FAIL_FLAG -ne 0 ]; then
	exit ${STF_FAIL}
fi

exit ${STF_PASS}
