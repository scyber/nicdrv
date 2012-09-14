#!/usr/bin/ksh
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
# ident	"@(#)ipmi.auto.ksh	1.1	09/06/24 SMI"
#

. ${STF_TOOLS}/include/stf.kshlib
. ${STF_SUITE}/include/common.kshlib

integer FAIL_FLAG=0

#
# Function ipmi_remote_test
# Run ipmitool command through remote LAN interface
# $1 IPMI IP 
# $2 remote host ip
# $2 IPMI command
# $3 IPMI pass word
#
ipmi_remote_test() 
{
	typeset ipmi_ip=$1
	typeset remote_ip=$2
	typeset cmd=$3
	typeset pass_word=$4
	typeset ipmi_user=$5
	rsh -n $remote_ip "echo $pass_word > /tmp/password"
	rsh -n $remote_ip "ipmitool -I lan -U $ipmi_user -f \
	    /tmp/password -H $ipmi_ip $cmd" > /tmp/ipmi.remote
	if [ ! -f /tmp/ipmi.remote ]; then
		echo "Can not display IPMI info"
		FAIL_FLAG=1
	fi
	echo "***Display IPMI info from remote host***"
	cat /tmp/ipmi.remote
}

#
# Function maxq_test
# Do maxq test on vlan interface
# Arguments:
# $1 - maxq test execution time
# $2 - product name
#
maxq_test() {
	typeset g_Time=$1
	typeset g_drv=$2
	typeset local_host=$3
	typeset remote_host=$4
	linkspeed=`get_linkspeed ${TST_INT} ${TST_NUM}`
	if [ "$linkspeed" = "0" ]; then
		echo "Failed: can't not get linkspeed"
		exit 1
	fi

	subnet_ip=`get_subnetip ${TST_INT} ${TST_NUM}`
	if [ "$subnet_ip" = "0" ]; then
		echo "Failed: can't not get subnet_ip"
		exit 1
	fi

	echo ${MAXQ_PATH}/MAXQ.auto \
	-s ${local_host} -c ${remote_host} -C ${remote_host} \
	-d 65535 -b 65535 -T $g_Time -M $subnet_ip -m root@localhost \
	-p nicdrv -i 1 -e $linkspeed -t 0 -tr bi -S 1 -P TCP_STREAM

	${MAXQ_PATH}/MAXQ.auto \
	-s ${local_host} -c ${remote_host} -C ${remote_host} \
	-d 65535 -b 65535 -T $g_Time -M $subnet_ip -m root@localhost \
	-p nicdrv -i 1 -e $linkspeed -t 0 -tr bi -S 1 -P TCP_STREAM

	if [ $? -ne 0 ]; then
		echo  "maxq test failed!"
		FAIL_FLAG=1
	else
		echo  "maxq test succeed!"
	fi
}

#
# Function check_status
# check the value of FAIL_FLAG 
#
check_status() {
	if [ $FAIL_FLAG -ne 0 ]; then
		echo "FAIL_FLAG=${FAIL_FLAG}"
		echo  "IPMI: IPMI test failed!"
		exit 1
	fi
}

#
# Function compare_ipmi
# Compare file1 and file2,then remove file1 and file2
#
compare_ipmi() {
	exec_cmd "cmp $1 $2"
	if [ $? -ne 0 ]; then
		echo  "IPMI: IPMI compare test failed"
		FAIL_FLAG=1
	fi
	exec_cmd "rm $1"
	exec_cmd "rm $2"
}

#
# Function cleanup
# Kill the exectuion process and delete vlan interfaces
#
cleanup () {
	pkill Ping.auto
	pkill MAXQ.auto
	plumb_unplumb_local_vlan unplumb 1 $g_vlan_num $g_drv $g_num
	plumb_unplumb_remote_vlan unplumb 1 $g_vlan_num $g_drv_rm $g_num_rm $g_rm_host
	delete_local_vlan 1 $g_vlan_num $g_drv $g_num $g_rm_host
	delete_remote_vlan 1 $g_vlan_num $g_drv $g_num_rm $g_rm_host
}

#
# Function Main
# Test vlan feature for Corssbow project
# Arguments:
# $1 - host machine ip address
# $2 - remote machine ip address
# $3 - host machine physical nic interface name
# $4 - host machine physical nic interface number
# $5 - remote machine physical nic interface name
# $6 - remote machine physical nic interface number
# $7 - ftp,nfscorrupt,maxq execution time
# $8 - vlan subnet perfix
# $9 - vlan num
#
g_lo_host=${1}
g_rm_host=${2}
g_drv=${3}
g_num=${4}
g_drv_rm=${5}
g_num_rm=${6}
g_time=${7}
g_vlan_subnet=${8}
g_vlan_num=${9}
g_ipmi_ip=${10}
g_ipmi_pass=${11}
g_ipmi_user=${12}
local_host=""
remote_host=""

trap "cleanup; exit 1" 1 2 3 9 15
echo "*****create $g_vlan_num vlans run net traffic*****"
create_local_vlan 1 $g_vlan_num $g_drv $g_num
plumb_unplumb_local_vlan plumb 1 $g_vlan_num $g_drv $g_num
local_host=$(set_vlan_local_ip_addr $g_vlan_subnet 1 $g_vlan_num $g_drv $g_num)

create_remote_vlan 1 $g_vlan_num $g_drv_rm $g_num_rm $g_rm_host
plumb_unplumb_remote_vlan plumb 1 $g_vlan_num $g_drv_rm $g_num_rm $g_rm_host
remote_host=$(set_vlan_remote_ip_addr $g_vlan_subnet 1 $g_vlan_num $g_drv_rm $g_num_rm $g_rm_host)
echo "*****local vlan interface*****"
ifconfig -a
echo "*****remote vlan interface*****"
rsh -n $g_rm_host "ifconfig -a"


check_tools_path
echo "******ping all size (0-1000) on ipmi interface*****"
${STF_SUITE}/tools/ping/Ping.auto \
	-c $g_ipmi_ip -t ping_all_size -s 1000 &
ping_pid=$(echo $!)
maxq_test $g_time $g_drv "$local_host,$g_lo_host" "$remote_host,$g_rm_host"
wait $ping_pid
if [ $? -ne 0 ]; then
	FAIL_FLAG=1
	echo "Ping.auto test on IPMI failed"
else
	echo "Ping.auto test on IPMI success"
fi

plumb_unplumb_local_vlan unplumb 1 $g_vlan_num $g_drv $g_num
plumb_unplumb_remote_vlan unplumb 1 $g_vlan_num $g_drv_rm $g_num_rm $g_rm_host
delete_local_vlan 1 $g_vlan_num $g_drv $g_num $g_rm_host
delete_remote_vlan 1 $g_vlan_num $g_drv $g_num_rm $g_rm_host

echo "*****run load/unload on $g_drv*****"
${STF_SUITE}/${STF_EXEC}/load_unload.auto \
	$g_lo_host $g_rm_host $g_drv $g_num 1 

echo "******ping all size (0-1000) on ipmi interface*****"
${STF_SUITE}/tools/ping/Ping.auto \
	-c $g_ipmi_ip -t ping_all_size -s 1000
if [ $? -ne 0 ]; then
	FAIL_FLAG=1
	echo "Ping.auto test on IPMI failed"
else
	echo "Ping.auto test on IPMI success"
fi

ipmi_remote_test $g_ipmi_ip $g_rm_host "lan print" $g_ipmi_pass $g_ipmi_user
compare_ipmi "/tmp/ipmi.local" "/tmp/ipmi.remote"
check_status
