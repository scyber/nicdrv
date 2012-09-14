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
# ident	"@(#)vlan.auto.ksh	1.7	09/06/24 SMI"
#

. ${STF_TOOLS}/include/stf.kshlib
. ${STF_SUITE}/include/common.kshlib

#
# Function clean_up
# clean up test environment
# Arguments: 
#
clean_plumb()
{
	plumb_unplumb_local_vlan unplumb 1 $g_max_vlan_id $g_drv $g_num
	delete_local_vlan 1 $g_max_vlan_id $g_drv $g_num 
}

#
# Function vlan_sanity_check
# Test "0,1,2,4093,4094,4095" vlan id
# Arguments: 
#
vlan_sanity_check() {
	echo "Start sanity plumb test"
	for vlan_id in 0 1 2 4093 4094 4095; do
		case "$vlan_id" in
		0 )
			create_local_vlan $vlan_id $vlan_id $g_drv $g_num
			if [ $? -eq 0 ]; then 
				FAIL_FLAG=1
			fi
			;;
		4095 )
			create_local_vlan $vlan_id $vlan_id $g_drv $g_num
			if [ $? -eq 0 ]; then 
				FAIL_FLAG=1
			fi

			plumb_unplumb_local_vlan plumb $vlan_id $vlan_id $g_drv $g_num
			if [ $? -eq 0 ]; then 
				FAIL_FLAG=1
			fi
			;;

		1 | 2 | 4093 | 4094 )
			create_local_vlan $vlan_id $vlan_id $g_drv $g_num
			if [ $? -ne 0 ]; then 
				FAIL_FLAG=1
			fi

			plumb_unplumb_local_vlan plumb $vlan_id $vlan_id $g_drv $g_num
			if [ $? -ne 0 ]; then 
				FAIL_FLAG=1
			fi
			;;
		esac
	done 
	echo "Start sanity unplumb test"
	for vlan_id in 0 1 2 4093 4094 4095; do
		case "$vlan_id" in
		0 )
			delete_local_vlan $vlan_id $vlan_id $g_drv $g_num
			if [ $? -eq 0 ]; then 
				FAIL_FLAG=1
			fi
		;;

		4095 )
			plumb_unplumb_local_vlan unplumb $vlan_id $vlan_id $g_drv $g_num
			if [ $? -eq 0 ]; then 
				FAIL_FLAG=1
			fi
			delete_local_vlan $vlan_id $vlan_id $g_drv $g_num
			if [ $? -eq 0 ]; then 
				FAIL_FLAG=1
			fi
		;;

		1 | 2 | 4093 | 4094 )
			plumb_unplumb_local_vlan unplumb $vlan_id $vlan_id $g_drv $g_num
			if [ $? -ne 0 ]; then 
				FAIL_FLAG=1
			fi
			delete_local_vlan $vlan_id $vlan_id $g_drv $g_num
			if [ $? -ne 0 ]; then 
				FAIL_FLAG=1
			fi
		;;
		esac
	done 
	echo "Tested vlanid 0 1 2 4093 4094 4095"
}

#
# Function vlan_plumb_test
# Do plumb/unplumb test on local machine 
# Arguments: 
# $1 start vlan id
# $2 end vlan id
#
vlan_plumb_test() {
	typeset g_vlan_id=$1
	typeset g_vlan_end=$2
	create_local_vlan 1 $g_vlan_end $g_drv $g_num

	while true; do
		[ $g_vlan_id -gt $g_vlan_end ] && break
		(( vppa = g_vlan_id * 1000 ))
		(( vppa = vppa + g_num ))
		ifconfig $g_drv$vppa plumb up
		if [ $? -ne 0 ]; then 
			FAIL_FLAG=1
			break
		fi
		(( g_vlan_id += 1 ))
		case "$g_vlan_id" in
		$(expr $g_vlan_end / 4) )
			echo "25% plumb test Done...(time)`date | awk '{print $4}'`"
			;;
		$(expr $g_vlan_end / 2) )
			echo "50% plumb test Done...(time)`date | awk '{print $4}'`"
			;;
		$(expr $g_vlan_end / 4 \* 3) )
			echo "75% plumb test Done...(time)`date | awk '{print $4}'`"
			;;
		$g_vlan_end)
			echo "100% plumb test Done...(time)`date | awk '{print $4}'`"
			;;
		esac
	done
	(( g_vlan_id -= 1 ))
	g_vlan_end=$g_vlan_id

	echo "*****************************************************"
	echo   plumb $g_vlan_end ppa successd on driver $g_drv !
	echo "*****************************************************"
	 sleep 5
	while true; do
		[ $g_vlan_id -lt 1 ] && break
		(( vppa = g_vlan_id * 1000 ))
		(( vppa = vppa + g_num ))
		ifconfig $g_drv$vppa unplumb
		if [ $? -ne 0 ]; then 
			FAIL_FLAG=1
			break
		fi
		case "$g_vlan_id" in
		$(expr $g_vlan_end / 4 \* 3) )
			echo "25% unplumb test Done...(time)`date | awk '{print $4}'`"
			;;
		$(expr $g_vlan_end / 2) )
			echo "50% unplumb test Done...(time)`date | awk '{print $4}'`"
			;;
		$(expr $g_vlan_end / 4) )
			echo "75% unplumb test Done...(time)`date | awk '{print $4}'`"
			;;
		1)
			echo "100% unplumb test Done...(time)`date | awk '{print $4}'`"
			;;
		esac
		(( g_vlan_id -= 1 ))
	done
	(( g_vlan_end = g_vlan_end - g_vlan_id ))
	echo "*****************************************************"
	echo   unplumb $g_vlan_end ppa successd on driver $g_drv !
	echo "*****************************************************"
	sleep 5
	echo "start id is $g_vlan_id end id is $g_vlan_end"
	delete_local_vlan 1 $g_vlan_end $g_drv $g_num 

}


#
# Function cleanup
# cleaup test environment,delete and unplumb vlan interfaces
#  on loacl and remote
# Arguments:
#
cleanup_vlan() {
	echo "clean up vlan interface."
	pkill Ping.auto
	pkill ftp.auto
	pkill Corrupt.auto
	pkill MAXQ.auto
	plumb_unplumb_local_vlan unplumb 1 $g_vlan_num $g_drv $g_num
	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
		echo "ERROR:unplumb local vlans failed"
	fi

	plumb_unplumb_remote_vlan unplumb 1 $g_vlan_num $g_drv_rm $g_num_rm $g_rm_host
	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
		echo "ERROR:unplumb remote vlans failed"
	fi

	delete_local_vlan 1 $g_vlan_num $g_drv $g_num 
	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
		echo "ERROR:delete local vlans failed"
	fi

	delete_remote_vlan 1 $g_vlan_num $g_drv $g_num_rm $g_rm_host
	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
		echo "ERROR:delete remote vlans failed"
	fi

}

#
# Function setup_vlan 
# setup test environment,create and plumb vlan interfaces
#  on loacl and remote
# Arguments:
#
setup_vlan() {
	create_local_vlan 1 $g_vlan_num $g_drv $g_num
	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
		echo "ERROR:create local vlans failed"
	fi

	plumb_unplumb_local_vlan plumb 1 $g_vlan_num $g_drv $g_num
	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
		echo "ERROR:plumb local vlans failed"
	fi
	local_host=$(set_vlan_local_ip_addr $g_vlan_subnet 1 $g_vlan_num $g_drv $g_num)

	create_remote_vlan 1 $g_vlan_num $g_drv_rm $g_num_rm $g_rm_host
	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
		echo "ERROR:create remote vlans failed"
	fi

	plumb_unplumb_remote_vlan plumb 1 $g_vlan_num $g_drv_rm $g_num_rm $g_rm_host
	if [ $? -ne 0 ]; then
		FAIL_FLAG=1
		echo "ERROR:plumb remote vlans failed"
	fi
	remote_host=$(set_vlan_remote_ip_addr $g_vlan_subnet \
	    1 $g_vlan_num $g_drv_rm $g_num_rm $g_rm_host)

	echo "*****show local ip interface*****"
	ifconfig -a
	echo "*****show remote ip interface*****"
	rsh -n $g_rm_host "ifconfig -a"
}


#
# Function maxq_test
# Do maxq test on vlan interface
# Arguments:
# $1 - maxq test execution time
# $2 - product name
# $3 - local interfaces ip array
# $4 - remote interfaces ip array
#
maxq_test() {
	typeset g_Time=$1
	typeset g_drv=$2
	typeset local_host=$3
	typeset remote_host=$4
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
		echo  "maxq test failed!"
		FAIL_FLAG=1
	else
		echo  "maxq test succeed!"
	fi
	cd ${OLD_PATH}
}

#
# Function ftp_test
# Do ftp test on vlan interface
# Arguments:
# $1 - ftp execution time
# $2 - product name
# $3 - remote machine password
# $4 - local interfaces ip array
# $4 - remote interfaces ip array
#
ftp_test() {
	typeset OLD_PATH=`pwd`
	typeset g_Time=$1
	typeset g_drv=$2
	typeset g_Rmpass=$3
	typeset local_host=$4
	typeset remote_host=$5

	cd ${FTP_PATH}
	echo ${FTP_PATH}/ftp.auto \
	    -r $remote_host -s 100m -t $g_Time -P $g_RmPASS \
	    -m "root@localhost" -p $g_drv -e 1

	${FTP_PATH}/ftp.auto \
	    -r $remote_host -s 100m -t $g_Time -P $g_Rmpass \
	    -m "root@localhost" -p $g_drv -e 1
	if [ $? -ne 0 ]; then
	echo  "vlan: ftp test failed!"
		FAIL_FLAG=1
	else
		echo  "vlan: ftp test succeed!"
	fi
	cd ${OLD_PATH}
}

#
# Function nfs_test
# Do nfscrrupt test on vlan interface
# Arguments:
# $1 - nfscrrupt test execution time
# $2 - product name
# $3 - local interfaces ip array
# $4 - remote interfaces ip array
#
nfs_test() {
	typeset g_Time=$1
	typeset g_drv=$2
	typeset local_host=$3
	typeset remote_host=$4
	typeset OLD_PATH=`pwd`
	echo ${NFS_PATH}/Corrupt.auto \
	    -c $remote_host -s $local_host -n 1 -t $g_Time \
	    -d bi -e "root@localhost" -p $g_drv -m udp -r no
	${NFS_PATH}/Corrupt.auto \
	    -c $remote_host -s $local_host -n 1 -t $g_Time \
	    -d bi -e "root@localhost" -p $g_drv -m udp -r no

	if [ $? -ne 0 ]; then
		echo  "vlan: nfscorrupt udp test failed!"
		FAIL_FLAG=1
	else
		echo  "vlan: nfscorrupt udp test succeed!"
	fi
	cd ${OLD_PATH}
}

#
#	Main
#
g_lo_host=$1
g_rm_host=$2
g_drv=$3
g_num=$4
g_drv_rm=$5
g_num_rm=$6
g_pass=$7
g_Time=$8
g_vlan_num=${9}
g_vlan_subnet=${10}
debug=0
FAIL_FLAG=0
g_max_vlan_id=$(get_parameter VLAN_ID_MAX)
local_host=""
remote_host=""

trap "cleanup_vlan; exit 1" 1 2 3 9 15


setup_vlan
check_tools_path
ftp_test $g_Time $g_drv $g_pass "$local_host" "$remote_host"
nfs_test $g_Time $g_drv "$local_host" "$remote_host"
maxq_test $g_Time $g_drv "$local_host" "$remote_host"

cleanup_vlan
vlan_sanity_check
trap "clean_plumb; exit 1" 1 2 3 9 15

vlan_plumb_test 1 $g_max_vlan_id
if [ $FAIL_FLAG -ne 0 ]; then
	echo  "vlan: VALN test failed!"
	exit 1
fi

echo  "vlan: all test succeed!"
exit 0
