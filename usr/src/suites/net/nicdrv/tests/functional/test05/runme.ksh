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
# ident	"@(#)runme.ksh	1.6	09/06/24 SMI"
#

###############################################################################
# __stc_assertion_start
#
# ID: tests/functional/test05
#
# DESCRIPTION:
#         Test NIC driver ndd interfaces with read/write operations
#
# STRATEGY:
#         - Read all "read only" ndd parameters supported by the NIC driver.
#         - Try to write all "read and write" ndd parameters.
#         - All operations should pass without any errors.
#         - Driver link/speed status should be recovered to original status.
#
# TESTABILITY: implicit
#
# AUTHOR: Robin.luo@Sun.COM
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

#
# This test case is to check ndd parameter's read-write privilige
#
. ${STF_TOOLS}/include/stf.kshlib
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

echo "ndd_1: Test all parameters read-write property"

if [ ! -L /dev/${TST_INT}${TST_NUM} ]; then
        echo "test interface does not exist"
        exit ${STF_UNSUPPORTED}
fi

dtrace_start "05" ${TST_INT}
dtr_pid=`echo $!`

ndd /dev/${TST_INT}${TST_NUM} \? > /dev/null

if [ $? -ne 0 ]; then
	echo "test interface does not support ndd"
	dtrace_end $dtr_pid "05"
	exit ${STF_UNSUPPORTED}
fi

unsupported_property=$(get_parameter NDD_UNSUPPORTED_PROPERTY)

orig_speed=`get_linkspeed ${TST_INT} ${TST_NUM}`
echo "original speed is $orig_speed..."

modinfo | grep ${TST_INT}

ndd /dev/${TST_INT}${TST_NUM} \? | while read LINE; do
        echo
        cur_para=`echo $LINE | awk '{print $1}'`
        echo $unsupported_property | grep "${TST_INT}:$cur_para" > /dev/null \
                && { echo "Skip unsupported property: $cur_para"; continue; }
        echo ${LINE} | grep "write"
        if [ $? -ne 0 ]; then
                echo "$cur_para is read only"
                echo "now read $cur_para, expect to be successful"
                ndd /dev/${TST_INT}${TST_NUM} $cur_para > /dev/null
                if [ $? -ne 0 ]; then
                        echo "$cur_para read fail!"
			dtrace_end $dtr_pid "05"
                        exit ${STF_FAIL}
                else
                        echo "$cur_para read successful as expected!"
                fi
                echo "now write $cur_para, expect to be fail"

                tst_value=0
		case $cur_para in
			"tx_recycle_thresh")	tst_value=2;;
			"tx_overload_thresh")	tst_value=2;;
			"tx_resched_thresh")	tst_value=2;;
			"rx_limit_per_intr")	tst_value=16;;
			"tx_interrupt_delay") tst_value=1024;;
			"max_num_rcv_packets") tst_value=512;;
			"tx_bcopy_threshold") tst_value=1024;;
			"tx_bcopy_frags_limit") tst_value=10;;
			"tx_recycle_low_water")	tst_value=16;;
			"tx_recycle_num")	tst_value=16;;
		esac			

                ndd -set /dev/${TST_INT}${TST_NUM} \
			$cur_para $tst_value > /dev/null
                if [ $? -ne 0 ]; then
                        echo "$cur_para write fail as expected!"
                else
                        echo "$cur_para write success, it is read-only!"
			dtrace_end $dtr_pid "05"
                        exit ${STF_FAIL}
                fi
        else
                echo "$cur_para is read and write"
                echo "now read $cur_para, expect to be successful"
                cur_para_old_value=`ndd /dev/${TST_INT}${TST_NUM} $cur_para`
                if [ $? -ne 0 ]; then
                        echo "$cur_para read fail!"
			dtrace_end $dtr_pid "05"
                        exit ${STF_FAIL}
                else
                        echo "$cur_para read successful as expected!"
                fi

                echo "now write $cur_para, expect to be successful"
                tst_value=0
		case $cur_para in
			"tx_recycle_thresh")	tst_value=2;;
			"tx_overload_thresh")	tst_value=2;;
			"tx_resched_thresh")	tst_value=2;;
			"rx_limit_per_intr")	tst_value=16;;
			"msi_cnt")	tst_value=7;;
			"tx_n_intr")	tst_value=1;;
			"drain_max")	tst_value=1;;
			"rxdma_intr_time")	tst_value=1;;
			"tx_interrupt_delay")	tst_value=1024;;
			"max_num_rcv_packets")	tst_value=512;;
			"tx_bcopy_threshold")	tst_value=1024;;
			"tx_bcopy_frags_limit")	tst_value=10;;
			"tx_recycle_low_water")	tst_value=16;;
			"tx_recycle_num")	tst_value=21;;
			"force_speed_duplex")	tst_value=1
						ndd -set /dev/${TST_INT}${TST_NUM} \
							adv_autoneg_cap 0;;
		esac
	
                ndd -set /dev/${TST_INT}${TST_NUM} \
			$cur_para $tst_value > /dev/null
                if [ $? -ne 0 ]; then
                        echo "$cur_para write fail!"
			if [ $cur_para = "force_speed_duplex" ]; then
				ndd -set /dev/${TST_INT}${TST_NUM} \
					adv_autoneg_cap 1
			fi
			dtrace_end $dtr_pid "05"
                        exit ${STF_FAIL}
                else
                        ndd -set /dev/${TST_INT}${TST_NUM} \
				$cur_para $cur_para_old_value > /dev/null
                        if [ $cur_para = "force_speed_duplex" ]; then
                                ndd -set /dev/${TST_INT}${TST_NUM} \
					adv_autoneg_cap 1
                        fi
                        echo "$cur_para write successful as expected!"
                fi
        fi
done

dtrace_end $dtr_pid "05"

check_host_alive $LOCAL_HST $RMT_HST
if [ $? -ne 0 ]; then
	echo "The client isn't alive, Test FAIL!"
	exit ${STF_FAIL}
else
	echo "The client is alive!"
fi

echo "show ${TST_INT}${TST_NUM} nic card info"
show_device | grep ${TST_INT}${TST_NUM}
cur_speed=`get_linkspeed ${TST_INT} ${TST_NUM}`
if [ $cur_speed != $orig_speed ]; then
	echo "Current speed is $cur_speed, recover failed"
	exit ${STF_FAIL}
fi


exit ${STF_PASS}
