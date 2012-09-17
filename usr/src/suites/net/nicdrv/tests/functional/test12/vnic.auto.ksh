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
# ident	"@(#)vnic.auto.ksh	1.3	09/06/24 SMI"
#

. ${STF_TOOLS}/include/stf_common.kshlib
. ${STF_SUITE}/include/common.kshlib

integer FAIL_FLAG=0
debug=0

#
# Function exec_cmd
# wrapper for execution command
# Arguments:
#  $1 - execution comand
#
exec_cmd() {
    typeset cmd=$1
    if [ $debug -eq 1 ]; then
	set -x
	$cmd
	set +x
    else
	$cmd
	if [ $? -ne 0 ]; then
          echo "$cmd Failed : result = $?"
	  FAIL_FLAG=1
        fi
    fi
}

#
# Function exec_cmd
# wrapper for execution remote command
# Arguments:
#  $1 - execution comand
#
exec_remote_cmd()
{
	typeset cmd=$1
	error=`rsh -n ${g_rm_host} "${cmd} > /dev/null 2>&1; echo \\\$?"`
	if [ $error -ne 0 ]; then
		echo "$cmd Failed:result = $error"
		FAIL_FLAG=1
	fi
	sleep 1
	
}

#
# Function ftp_test
# Do ftp test on vnic interface
# Arguments:
# $1 - ftp execution time
# $2 - product name
# $3 - remote machine password
#
ftp_test() {
	typeset OLD_PATH=`pwd`
	typeset g_Time=$1
	typeset g_drv=$2
	typeset g_Rmpass=$3
	cd ${FTP_PATH}
	echo ${FTP_PATH}/ftp.auto \
	    -r $remote_host -s 100m -t $g_Time -P $g_Rmpass \
	    -m "root@localhost" -p $g_drv -e 1

	${FTP_PATH}/ftp.auto \
	    -r $remote_host -s 100m -t $g_Time -P $g_Rmpass \
	    -m "root@localhost" -p $g_drv -e 1
	if [ $? -ne 0 ]; then
	echo  "vnic: ftp test failed!"
		FAIL_FLAG=1
	else
		echo  "vnic: ftp test succeed!"
	fi
	cd ${OLD_PATH}
}

#
# Function nfs_test
# Do nfscrrupt test on vnic interface
# Arguments:
# $1 - nfscrrupt test execution time
# $2 - product name
#
nfs_test() {
	typeset g_Time=$1
	typeset g_drv=$2
	typeset OLD_PATH=`pwd`
	echo ${NFS_PATH}/Corrupt.auto \
	    -c $remote_host -s $local_host -n 1 -t $g_Time \
	    -d bi -e "root@localhost" -p $g_drv -m udp -r no
	${NFS_PATH}/Corrupt.auto \
	    -c $remote_host -s $local_host -n 1 -t $g_Time \
	    -d bi -e "root@localhost" -p $g_drv -m udp -r no

	if [ $? -ne 0 ]; then
		echo  "vnic: nfscorrupt udp test failed!"
		FAIL_FLAG=1
	else
		echo  "vnic: nfscorrupt udp test succeed!"
	fi
	cd ${OLD_PATH}
}

#
# Function maxq_test
# Do maxq test on vnic interface
# Arguments:
# $1 - maxq test execution time
# $2 - product name
#
maxq_test() {
	typeset g_Time=$1
	typeset g_drv=$2
	typeset OLD_PATH=`pwd`
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
		echo  "vnic: maxq test failed!"
		FAIL_FLAG=1
	else
		echo  "vnic: maxq test succeed!"
	fi
	cd ${OLD_PATH}
}

#
# Function check_status
# check the value of FAIL_FLAG 
#
check_status() {
	if [ $FAIL_FLAG -ne 0 ]; then
		echo "FAIL_FLAG=${FAIL_FLAG}"
		echo  "vnic: vnic test failed!"
		exit 1
	fi
}

#
# Function show_link_prop
# Show the link priority 
#
show_link_prop() {
	dladm show-linkprop | grep priority | grep ${g_base_name}
}

#
# Function show_local_ip_addr
# Show the local machine ip address
#
show_local_ip_addr() {
	exec_cmd "ifconfig -a"
}

#
# Function show_remote_ip_addr
# Show the remote machine ip address
#
show_remote_ip_addr() {
	rsh -n ${g_rm_host} ifconfig -a
}

#
# Function plumb_unplumb_test
# Do plumb unplumb on local host and remote server
# Arguments:
# $1 - mac_flag(random,fixed) 
# $2 - count plumb,unplumb times
# $3 - vnic priority(low,high) 
#
plumb_unplumb_test() {
    	typeset mac_flag=$1
	typeset count=$2
	typeset pri=$3
	create_local_vnic ${g_drv}${g_num} ${mac_flag} ${count} ${pri} 0 ${g_base_name}
	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
		echo "ERROR:create local vnics failed"
	fi

	plumb_unplumb_local_vnic plumb ${count} ${g_base_name}
	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
		echo "ERROR:plumb local vlans failed"
	fi

	sleep 5
	plumb_unplumb_local_vnic unplumb ${count} ${g_base_name}
	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
		echo "ERROR:unplumb local vlans failed"
	fi

	delete_local_vnic ${count} ${g_base_name}
	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
		echo "ERROR:delete local vlans failed"
	fi
}

#
# Function net_traffic_test
# Create vnic with high or low priority,Run maxq,nfscorrupt,ftp on vnic 
# Arguments:
# $1 - vnic interface numbers to be created
# $2 - vnic interface priority(low,high)
# $3 - mode(all,mix) all(all the vnic interface will use same priority),
#	mix(half number interface use same priority)
#
net_traffic_test() {
	typeset count=$1
	typeset mode=$2 
	typeset pri=$3
	typeset halfcount=`expr $count / 2`
	if [ $mode == "all" ]; then
		create_local_vnic ${g_drv}${g_num} random \
		    ${count} ${pri} 0 ${g_base_name} || FAIL_FLAG=1
		create_remote_vnic ${g_drv_rm}${g_num_rm} random \
		    ${count} ${pri} 0 ${g_base_name} ${g_rm_host} || FAIL_FLAG=1
	fi
	if [ $mode == "mix" ]; then
		create_local_vnic ${g_drv}${g_num} random \
		    ${halfcount} low 0 ${g_base_name} || FAIL_FLAG=1
		create_local_vnic ${g_drv}${g_num} random \
		    ${halfcount} high ${halfcount} ${g_base_name} || FAIL_FLAG=1
		create_remote_vnic ${g_drv_rm}${g_num_rm} random \
		    ${halfcount} low 0 ${g_base_name} ${g_rm_host} || FAIL_FLAG=1
		create_remote_vnic ${g_drv_rm}${g_num_rm} random \
		    ${halfcount} high ${halfcount} ${g_base_name} ${g_rm_host} || FAIL_FLAG=1

	fi

	plumb_unplumb_local_vnic plumb ${count} ${g_base_name} || FAIL_FLAG=1
	plumb_unplumb_remote_vnic plumb ${count} ${g_base_name} ${g_rm_host} || FAIL_FLAG=1
	local_host=$(set_vnic_local_ip_addr 220.0 ${count} ${g_base_name}) 
	remote_host=$(set_vnic_remote_ip_addr 220.0 ${count} ${g_base_name} ${g_rm_host})
	echo "*****local ip address*****"
	show_local_ip_addr
	echo "*****remote ip address*****"
	show_remote_ip_addr
	echo "****show link priority*****"
	show_link_prop 
	ftp_test $g_Time $g_drv $g_Rmpass
	nfs_test $g_Time $g_drv
	maxq_test $g_Time $g_drv
	sleep 10
	plumb_unplumb_local_vnic unplumb ${count} ${g_base_name} || FAIL_FLAG=1
	plumb_unplumb_remote_vnic unplumb ${count} ${g_base_name} ${g_rm_host} || FAIL_FLAG=1
	delete_local_vnic ${count} ${g_base_name} || FAIL_FLAG=1
	delete_remote_vnic ${count} ${g_base_name} ${g_rm_host} || FAIL_FLAG=1
}

#
# Function cleanup
# Kill the exectuion process and delete vnic interfaces
#
cleanup () {
   	typeset count=$1
	if [ $count -lt 50 ]; then
	    count=50
	fi
	pkill ftp.auto
	pkill Corrupt.auto
	pkill MAXQ.auto
	plumb_unplumb_local_vnic unplumb ${count}  ${g_base_name}
	plumb_unplumb_remote_vnic unplumb ${count} ${g_base_name} ${g_rm_host}
	delete_local_vnic ${count} ${g_base_name}
	delete_remote_vnic ${count} ${g_base_name} ${g_rm_host}
}

#
# Function Main
# Test vnic feature for Corssbow project
# Arguments:
# $1 - host machine ip address
# $2 - remote machine ip address
# $3 - host machine physical nic interface name
# $4 - host machine physical nic interface number
# $5 - remote machine physical nic interface name
# $6 - remote machine physical nic interface number
# $7 - remote machine ftp password
# $8 - ftp,nfscorrupt,maxq execution time
# $9 - vnic interface name perfix
#
g_lo_host=${1}
g_rm_host=${2}
g_drv=${3}
g_num=${4}
g_drv_rm=${5}
g_num_rm=${6}
g_Rmpass=${7}
g_Time=${8}
g_base_name=${9}
g_vnic_count=${10}
g_vnic_count_low=`expr $g_vnic_count - 1`
g_vnic_count_high=`expr $g_vnic_count + 1`

local_host=""
remote_host=""

if [ ${g_vnic_count_low} -eq 0 ]; then
	g_vnic_count_low=1
fi

trap "cleanup ${g_vnic_count}; exit 1" 1 2 3 9 15

check_tools_path
echo "*****start plumb unplumb test with random mac address 50 low*****"
plumb_unplumb_test random 50 low
echo "*****start traffic test with low priority*****"
net_traffic_test  ${g_vnic_count_high} all low
echo "*****start traffic test with high priority*****"
net_traffic_test  ${g_vnic_count_low} all high
echo "*****vnic test finish*****"
check_status
