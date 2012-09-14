#!/bin/sh
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
# ident	"@(#)MAXQ.auto.sh	1.5	08/11/12 SMI"
#

###############################################################################
# verify rsh call return, 0=success, non-zero=failure
# verify_rsh ret rcmd
###############################################################################
verify_rsh()
{
  if [ $1 -ne 0 ]
  then
      echo "$2: FAILED"
  fi
}

###############################################################################
# verify computer has installed the netperf
###############################################################################
check_netperf () {
	bin_dir=`isainfo -n`
	NETPERF_HOME=${NETPERF_HOME:-"${STF_TOOLS}/../SUNWstc-netperf2/bin/"}
	echo "NETPERF_HOME=$NETPERF_HOME"
	if [ ! -f $NETPERF_HOME/$bin_dir/netperf ]; then
		echo "Couldn't not find netperf tools, \
		    please verify it is installed in proper location."
		exit
        fi
}

###############################################################################
# print the command line usage info
###############################################################################
usage()
{
  echo "Usage: $0 -b buf_size -l logdir -m mailto -M mcast_subnet "
  echo "          -p product -s \"svr1,svr2,..., svrN\" "
  echo "          -c \"cli1,cli2,...,cliN\" -C maxq_client"
  echo "          -d datasize"
  echo "          -i interface_per_card "
  echo "          -e link_speed "
  echo "          -t maxq_type"
  echo "          -tr maxq_traffic_type"
  echo "          -D tcp_nodelay_mode"
  echo "          -S session_per_interface"
  echo "          -P protocol_type"
  echo "          -TMI TEST_MATRIX_ID"
  echo "$0                                FAILED"
}

#########################################################################
# Setup ENVs, install, configure test envrionments
# Usage: setup -b buf_size -l logdir -m mailto -p product
#              -s "svr1,svr2,...,svrN" -c \"cli1 ... cliN\""
#              -d datasize
#              -D tcp_nodelay_mode
#              -C maxq_client
#              -M multicast_subnet
#              -i interface_per_card -e link_speed
#              -S session_per_interface -t maxq_type
#	       -tr maxq_traffic_type
#              -P protocol_type
#              -TMI TEST_MATRIX_ID
# return values: 0 - success
#                1 - failure
#########################################################################
setup()
{
  #set -x
  if [ -f ./.${TESTNAME}rc ]
  then
    . ./.${TESTNAME}rc
  fi

  # processing command line options
  echo "Command:  $PROG $*"
  for i in $*
  do
    case $1 in
            -b)  MAXQ_BUF_SIZE=$2
                 export MAXQ_BUF_SIZE
                 shift 2
                 ;;
            -d)  MAXQ_DATA_SIZE=$2
                 export MAXQ_DATA_SIZE
                 shift 2
                 ;;
            -D)  MAXQ_TCP_NODELAY=$2
                 export MAXQ_TCP_NODELAY
                 shift 2
                 ;;
            -e)  INTERFACE_SPEED=$2
                 export INTERFACE_SPEED
                 shift 2
                 ;;
            -i)  INTERFACE_PER_CARD=$2
                 export INTERFACE_PER_CARD
                 shift 2
                 ;;
            -l)  LOGDIR=$2
                 export LOGDIR
                 shift 2
                 ;;
            -m)  MAILTO=$2
                 export MAILTO
                 shift 2
                 ;;
            -M)  MULTICAST_SUBNET=$2
                 export MULTICAST_SUBNET
                 shift 2
                 ;;
            -p)  PRODUCT=$2
                 export PRODUCT
                 shift 2
                 ;;
            -P)  PROTOCOL_TYPE=$2
                 export PROTOCOL_TYPE
                 shift 2
                 ;;
            -s)  MAXQ_SUT_IF=$2
                 export MAXQ_SUT_IF
                 shift 2
                 ;;
            -S)  SESSION_PER_INTERFACE=$2
                 export SESSION_PER_INTERFACE
                 shift 2
                 ;;
            -c)  MAXQ_CLI_IF=$2
                 export MAXQ_CLI_IF
                 shift 2
                 ;;
            -C)  MAXQ_CLIENT=$2
                 export MAXQ_CLIENT
                 shift 2
                 ;;
            -t)  MAXQ_TYPE=$2
                 export MAXQ_TYPE
                 shift 2
                 ;;
            -tr) MAXQ_TRAFFIC_TYPE=$2
                 export MAXQ_TRAFFIC_TYPE
                 shift 2
                 ;;
            -T)  MAXQ_RUN_TIME=$2
                 export MAXQ_RUN_TIME
                 shift 2
                 ;;
            -TMI) TEST_MATRIX_ID=$2
                 export TEST_MATRIX_ID
                 shift 2
                 ;;
            -*)  usage
                 echo "FAILED : Invalid option: $1"
                 return 1
                 ;;
    esac
  done

  # MAXQ test system requirement warning, stop test if not meet
  if [ ${MAXQ_TYPE} = "1" ]; then
    more -20 prerequisite.txt
    echo "========================================================"
    echo ""
    echo "If you anwsered \"NO\" for any of above listed questions,"
    echo "        press \"CONTROL-C\""
    echo ""
    echo "now to stop the measurement, otherwise"
    echo "        press \"RETURN\" to continue"
    echo ""
    read input
  else
    INTERFACE_PER_CARD=1; export INTERFACE_PER_CARD
  fi

  # Must be root to run this test
  echo "Checking super-user permission..."
  if [ -f /usr/bin/whoami ]; then
    WHOAMI=/usr/bin/whoami
  else
    WHOAMI=/usr/ucb/whoami
  fi
  if [ `${WHOAMI}` != "root" ]; then
    echo "setup() FAILED :  you must be root"
    if [ ${sut_os} = "SunOS" ]; then
      mailx -s "${TESTNAME}: you must be root" ${MAILTO} </dev/null
    elif [ ${sut_os} = "Linux" ]; then
      mail -s "${TESTNAME}: you must be root" ${MAILTO} </dev/null
    fi
    return 1
  fi

  mkdir -p ${LOGDIR}
  # Verify mandatory parameters
  echo "Verifying mandatory parameters..."
  if [ "X${MAXQ_SUT_IF}" = "X" ]
  then
    echo "FAILED : MAXQ_SUT_IF not set in .${TESTNAME}rc? CLI options?"
    if [ ${sut_os} = "SunOS" ]; then
      mailx -s "$TESTNAME: MAXQ_SUT_IF not set" $MAILTO </dev/null
    elif [ ${sut_os} = "Linux" ]; then
      mail -s "${TESTNAME}: MAXQ_SUT_IF not set" ${MAILTO} </dev/null
    fi
    return 1
  fi

  if [ "X${INTERFACE_PER_CARD}" = "X" ]
  then
    echo "FAILED : INTERFACE_PER_CARD not set in .${TESTNAME}rc? CLI options?"
    if [ ${sut_os} = "SunOS" ]; then
      mailx -s "$TESTNAME: INTERFACE_PER_CARD not set" $MAILTO </dev/null
    elif [ ${sut_os} = "Linux" ]; then
      mail -s "${TESTNAME}: INTERFACE_PER_CARD not set" ${MAILTO} </dev/null
    fi
    return 1
  fi

  if [ "X${INTERFACE_SPEED}" = "X" ]
  then
    echo "FAILED : INTERFACE_SPEED not set in .${TESTNAME}rc? CLI options?"
    if [ ${sut_os} = "SunOS" ]; then
      mailx -s "$TESTNAME: INTERFACE_SPEED not set" $MAILTO </dev/null
    elif [ ${sut_os} = "Linux" ]; then
      mail -s "${TESTNAME}: INTERFACE_SPEED not set" ${MAILTO} </dev/null
    fi
    return 1
  fi

  # the TP drop % to be considered end of the test
  if [ $INTERFACE_SPEED -ge 4000 ]; then
    stop_flag=85
  elif [ $INTERFACE_SPEED -ge 1000 ]; then
    stop_flag=85
  elif [ $INTERFACE_SPEED -ge 400 ]; then
    stop_flag=90
  elif [ $INTERFACE_SPEED -ge 100 ]; then
    stop_flag=95
  elif [ $INTERFACE_SPEED -ge 10 ]; then
    stop_flag=97
  else
    stop_flag=98
  fi

  if [ "X${MAXQ_CLIENT}" = "X" ]
  then
    echo "FAILED : MAXQ_CLIENT not set in .${TESTNAME}rc? CLI options?"
    if [ ${sut_os} = "SunOS" ]; then
      mailx -s "$TESTNAME: MAXQ_CLIENT not set" $MAILTO </dev/null
    elif [ ${sut_os} = "Linux" ]; then
      mail -s "${TESTNAME}: MAXQ_CLIENT not set" ${MAILTO} </dev/null
    fi
    return 1
  fi

  if [ "X${MAXQ_CLI_IF}" = "X" ]
  then
    echo "FAILED : MAXQ_CLI_IF not set in .${TESTNAME}rc? CLI options?"
    if [ ${sut_os} = "SunOS" ]; then
      mailx -s "$TESTNAME: MAXQ_CLI_IF not set" $MAILTO </dev/null
    elif [ ${sut_os} = "Linux" ]; then
      mail -s "${TESTNAME}: MAXQ_CLI_IF not set" ${MAILTO} </dev/null
    fi
    return 1
  fi

  if [ "X${PRODUCT}" = "X" ]
  then
    echo "FAILED : PRODUCT not set in .${TESTNAME}rc? CLI options?"
    if [ ${sut_os} = "SunOS" ]; then
      mailx -s "$TESTNAME: PRODUCT not set" $MAILTO </dev/null
    elif [ ${sut_os} = "Linux" ]; then
      mail -s "${TESTNAME}: PRODUCT not set" ${MAILTO} </dev/null
    fi
    return 1
  fi

  if [ "X${MULTICAST_SUBNET}" = "X" -a ${MAXQ_TYPE} -ne 0 ]
  then
    echo "FAILED : performance test not synchronized"
    if [ ${sut_os} = "SunOS" ]; then
      mailx -s "$TESTNAME: performance test not synchronized" $MAILTO </dev/null
    elif [ ${sut_os} = "Linux" ]; then
      mail -s "${TESTNAME}: performance test not synchronized" ${MAILTO} </dev/null
    fi
    return 1
  fi

  if [ ${MAXQ_TCP_NODELAY} -ne 0 ]
  then
    echo "TCP_NODELAY is on"
  else
    echo "TCP_NODELAY is off"
  fi

  if [ "X${PROTOCOL_TYPE}" != "XTCP_STREAM" ] &&
     [ "X${PROTOCOL_TYPE}" != "XUDP_STREAM" ] &&
     [ "X${PROTOCOL_TYPE}" != "XTCP_RR" ] &&
     [ "X${PROTOCOL_TYPE}" != "XTCP_CRR" ] &&
     [ "X${PROTOCOL_TYPE}" != "XUDP_RR" ] &&
     [ "X${PROTOCOL_TYPE}" != "XTCPIPV6_STREAM" ] &&
     [ "X${PROTOCOL_TYPE}" != "XUDPIPV6_STREAM" ] &&
     [ "X${PROTOCOL_TYPE}" != "XTCPIPV6_RR" ] &&
     [ "X${PROTOCOL_TYPE}" != "XTCPIPV6_CRR" ] &&
     [ "X${PROTOCOL_TYPE}" != "XUDPIPV6_RR" ]
  then
    PROTOCOL_TYPE="TCP_STREAM"; export PROTOCOL_TYPE
  fi

  # IP v4 or IP v6 detection
  if [ "X${PROTOCOL_TYPE}" != "XTCP_STREAM" ] &&
       [ "X${PROTOCOL_TYPE}" != "XUDP_STREAM" ] &&
       [ "X${PROTOCOL_TYPE}" != "XTCP_RR" ] &&
       [ "X${PROTOCOL_TYPE}" != "XTCP_CRR" ] &&
       [ "X${PROTOCOL_TYPE}" != "XUDP_RR" ]; then
      ip_version=6; export ip_version
  else
      ip_version=4; export ip_version
  fi

  if [ "X${MAXQ_TRAFFIC_TYPE}"  != "Xrx" ] &&
     [ "X${MAXQ_TRAFFIC_TYPE}"  != "Xtx" ]
  then
    MAXQ_TRAFFIC_TYPE="bi"; export MAXQ_TRAFFIC_TYPE
  fi

  # MAXQ_TYPE=1 only support TCP_STREAM and TCPIPV6_STREAM
  if [ ${MAXQ_TYPE} = "1" ]; then
    if [ "X${PROTOCOL_TYPE}" != "XTCP_STREAM" ] &&
         [ "X${PROTOCOL_TYPE}" != "XUDP_STREAM" ] &&
         [ "X${PROTOCOL_TYPE}" != "XTCP_RR" ] &&
         [ "X${PROTOCOL_TYPE}" != "XTCP_CRR" ] &&
         [ "X${PROTOCOL_TYPE}" != "XUDP_RR" ]; then
      PROTOCOL_TYPE="TCPIPV6_STREAM"; export PROTOCOL_TYPE
    else
      PROTOCOL_TYPE="TCP_STREAM"; export PROTOCOL_TYPE
    fi
    # MAXQ_TRAFFIC_TYPE must be "bi" for MAXQ_TYPE=1
    MAXQ_TRAFFIC_TYPE="bi"; export MAXQ_TRAFFIC_TYPE
  fi

  # check UDP packet size
  if [ "X${PROTOCOL_TYPE}" = "XUDP_STREAM" ] ||
     [ "X${PROTOCOL_TYPE}" = "XUDPIPV6_STREAM" ]
  then
     echo "Checking UDP packet sizes..."
     if [ ${MAXQ_DATA_SIZE} -gt 49152 ]; then
        echo "Warning: UDP packet size ${MAXQ_DATA_SIZE} too large"
        echo "  set MAXQ_DATA_SIZE=49152 for the testing..."
        MAXQ_DATA_SIZE="49152"; export MAXQ_DATA_SIZE
     fi
  fi

  # check MAXQ_TRAFFIC_TYPE for RR type tests
  if [ "X${PROTOCOL_TYPE}" = "XTCP_RR" ] ||
     [ "X${PROTOCOL_TYPE}" = "XTCP_CRR" ] ||
     [ "X${PROTOCOL_TYPE}" = "XUDP_RR" ] ||
     [ "X${PROTOCOL_TYPE}" = "XTCPIPV6_RR" ] ||
     [ "X${PROTOCOL_TYPE}" = "XTCPIPV6_CRR" ] ||
     [ "X${PROTOCOL_TYPE}" = "XUDPIPV6_RR" ]
  then
    MAXQ_TRAFFIC_TYPE="bi"; export MAXQ_TRAFFIC_TYPE
  fi

  # convert from "host1,host2" to "host1 host2" format
  MAXQ_SUT_IF=`echo $MAXQ_SUT_IF | sed 's/,/ /g'`; export MAXQ_SUT_IF
  MAXQ_CLI_IF=`echo $MAXQ_CLI_IF | sed 's/,/ /g'`; export MAXQ_CLI_IF
  MAXQ_CLIENT=`echo $MAXQ_CLIENT | sed 's/,/ /g'`; export MAXQ_CLIENT

  # make sure num of servers = num of clients
  echo "Verifying client <-> server pairs..."
  nsvr=`echo $MAXQ_SUT_IF | awk '{print NF}'`
  nclt=`echo $MAXQ_CLI_IF | awk '{print NF}'`
  if [ $nsvr -ne $nclt ]; then
      echo "FAILED : num of servers($nsvr) != num of clients($nclt)"
      if [ ${sut_os} = "SunOS" ]; then
        mailx -s "$TESTNAME: num of servers != num of clients" $MAILTO </dev/null
      elif [ ${sut_os} = "Linux" ]; then
        mail -s "${TESTNAME}: num of servers != num of clients" ${MAILTO} </dev/null
    fi
      return 1
  fi

  # make sure MAXQ_SUT_IF is the local system
  echo "Verifying MAXQ.auto is running on SUT system..."
  for host in $MAXQ_SUT_IF
  do
    tmphost=`rsh -n ${host} "hostname"`
    if [ "X${tmphost}" != "X${HOSTNAME}" ]
    then
      echo "FAILED : MAXQ_SUT_IF contain non-local hostnames $host"
      if [ ${sut_os} = "SunOS" ]; then
        mailx -s "$TESTNAME: MAXQ_SUT_IF contain non-local hostname" $MAILTO </dev/null
      fi
      return 1
    fi
  done

  # distributing binary executables and set tcp_time_wait_interval
  echo "Detecting system and distributing binaries..."
  for host in ${MAXQ_CLI_IF} `hostname`
  do
    host_os=`rsh -n ${host} uname -s`
    host_hw=`rsh -n ${host} uname -p`
    host_ver=`rsh -n ${host} uname -r`
    if [ "X${host_os}" = "XSunOS" ]; then
      #################################
      # Tune tcp_time_wait_interval
      #################################
      rsh -n ${host} "if [ ! -f /tmp/ndd.time_wait.sav ]; then \
                     ndd /dev/tcp tcp_time_wait_interval \
                     > /tmp/ndd.time_wait.sav; \
                   fi"
      verify_rsh $? ${host}_ndd_sav
      rsh -n ${host} "ndd -set /dev/tcp tcp_time_wait_interval $tcp_time_wait_interval"
      verify_rsh $? ${host}_ndd
    fi

    bin_dir=`isainfo -n`
    if [ ! -f ${NETPERF_HOME}/${bin_dir}/${NET_SERVER} ]; then
      echo "setup() FAILED : ${NETPERF_HOME}/${bin_dir}/${NET_SERVER} not found"
      echo "  please contact testsuite owner with the platform available"
      if [ ${sut_os} = "SunOS" ]; then
        mailx -s "$TESTNAME: ${NETPERF_HOME}/${bin_dir}/${NET_SERVER} not found" $MAILTO </dev/null
      elif [ ${sut_os} = "Linux" ]; then
        mail -s "${TESTNAME}: ${NETPERF_HOME}/${bin_dir}/${NET_SERVER} not found" ${MAILTO} </dev/null
      fi
      return 1
    fi
    
    rmt_bin_dir=`rsh ${host} isainfo -n`
    rcp ${NETPERF_HOME}/${rmt_bin_dir}/* ${host}:/tmp
    rcp ${STF_SUITE}/tools/maxq/${STF_BUILD_MODE}/start_netperf ${host}:/tmp/start_netperf.sh
  done

  # setup multicast routing table on driver machine
  if [ "X${MULTICAST_SUBNET}" != "X" ]
  then
    if [ ${sut_os} = "SunOS" ]; then
      sut_if=`route -n get ${MULTICAST_SUBNET} | grep interface | awk '{print $2}'`
      if [ `echo $sut_if | wc -w` -gt 1 ]; then
        echo "setup() FAILED: Multiple interfaces configured in ${MULTICAST_SUBNET} subnet."
        echo "$sut_if"
        mailx -s "${TESTNAME}: Multi-interfaces in ${MULTICAST_SUBNET} subnet" ${MAILTO} < /dev/null
        return 1
      fi
    elif [ ${sut_os} = "Linux" ]; then
      sut_if_old=`netstat -rn | grep 224.0.0.0 | awk '{print $8}'`
      export sut_if_old
      sut_if=`netstat -rn | grep ${MULTICAST_SUBNET} | awk '{print $8}'`
      if [ `echo $sut_if | wc -w` -gt 1 ]; then
        echo "setup() FAILED: Multiple interfaces configured in ${MULTICAST_SUBNET} subnet."
        echo "$sut_if"
        mail -s "${TESTNAME}: Multi-interfaces in ${MULTICAST_SUBNET} subnet" ${MAILTO} < /dev/null
        return 1
      fi
    fi
    export sut_if

    echo "Setting up multicasting subnet..."
    mg_cur=`netstat -rn | grep 224.0.0.0 | awk '{print $2}'`
    export mg_cur
    mg_new=`netstat -rn | grep ${MULTICAST_SUBNET} | awk '{print $2}'`
    export mg_new
    if [ "X${mg_cur}" = "X" ]; then
      if [ ${sut_os} = "SunOS" ]; then
        route add -interface 224.0.0.0 -netmask 240.0.0.0 -gateway ${mg_new}
      elif [ ${sut_os} = "Linux" ]; then
        route add -net 224.0.0.0 netmask 240.0.0.0 ${sut_if}
      fi
    elif [ "X${mg_cur}" != "X${mg_new}" ]; then
      if [ ${sut_os} = "SunOS" ]; then
        route delete 224.0.0.0 -netmask 240.0.0.0 ${mg_cur}
        route add -interface 224.0.0.0 -netmask 240.0.0.0 -gateway ${mg_new}
      elif [ ${sut_os} = "Linux" ]; then
        route del -net 224.0.0.0 netmask 240.0.0.0 ${sut_if_old}
        route add -net 224.0.0.0 netmask 240.0.0.0 ${sut_if}
      fi
    elif [ "X${mg_new}" = "X0.0.0.0" ]; then
      if [ ${sut_os} = "Linux" ]; then
        route del -net 224.0.0.0 netmask 240.0.0.0 ${sut_if_old}
        route add -net 224.0.0.0 netmask 240.0.0.0 ${sut_if}
      fi
    fi
    echo "Multicast subnet gateway: ${mg_new}/${sut_if}"
  fi

  return 0
}

###############################################################################
# routine to read "logfile" and calculate throughput data
# usage: get_throughput logfile
###############################################################################
get_throughput()
{
  total_tp=`awk '$5~/^[0-9]*\.[0-9]*$/{x+=$5}END{printf("%.0f",x)} ' \$1`
}

###############################################################################
# routine to measure throughput for a fixed number of cards/sessions 
#
# usage: get_TP #cards #session_per_interface #running_seconds
#
###############################################################################
get_TP()
{
  #set -x

  echo "Running get_TP on card=$1 sess=$2 time=$3 for performance..."

  l_card=$1           # number of interface card
  l_sess=$2           # SESSION_PER_INTERFACE pair
  l_timeout=$3        # running time in seconds
  # get number of hosts in ${MAXQ_SUT_IF}
  field=`expr $l_card \* $INTERFACE_PER_CARD`
   

  #########################################################################
  # turn on or off tcp_nodelay flag
  #########################################################################
  if [ ${MAXQ_TCP_NODELAY} -ne 0 ]
  then
    tcp_nodelay="-D"; export tcp_nodelay
  else
    tcp_nodelay=""; export tcp_nodelay
  fi

  #########################################################################
  # find the interface being used for multicast on test systems, then
  # start ${NET_SERVER} if it is not running
  #########################################################################
  for host in ${MAXQ_CLI_IF} ${HOSTNAME}
  do
    host_os=""
    host_os=`rsh -n ${host} uname -s`
    if [ "X${host_os}" = "XSunOS" ]; then
      if [ "X${MULTICAST_SUBNET}" != "X" ]; then
        mif=`rsh -n ${host} "route -n get ${MULTICAST_SUBNET}" | grep interface | awk '{print \$2}' | sort`
	if [ `echo $mif | wc -w` -gt 1 ]; then
	  echo "Warning: Multiple interfaces in ${MULTICAST_SUBNET} subnet."
	  echo "$mif"
	  mif=`echo $mif | awk '{print $1}'`
	  echo "         $mif being picked for multicast"
	fi
        m_mode=""; export m_mode
      fi
    elif [ "X${host_os}" = "XLinux" ]; then
      if [ "X${MULTICAST_SUBNET}" != "X" ]; then
        mif=`rsh -n ${host} netstat -rn | grep ${MULTICAST_SUBNET} | awk '{print \$8}' | sort`
	if [ `echo $mif | wc -w` -gt 1 ]; then
	  echo "Warning: Multiple interfaces in ${MULTICAST_SUBNET} subnet."
	  echo "$mif"
	  mif=`echo $mif | awk '{print $1}'`
	  echo "         $mif being picked for multicast"
	fi
        m_mode=""; export m_mode
      fi
    else
      echo "get_TP: rsh -n ${host} uname -s return ${host_os}"
      echo "MAXQ.auto aborted due to rsh failure"
      if [ ${sut_os} = "SunOS" ]; then
        mailx -s "${PRODUCT}: ${TESTNAME} results on ${HOSTNAME}" ${MAILTO} < ${LOGFILE}
      elif [ ${sut_os} = "Linux" ]; then
        mail -s "${PRODUCT}: ${TESTNAME} results on ${HOSTNAME}" ${MAILTO} < ${LOGFILE}
      fi
      exit 1
    fi
    if [ "X${host}" = "X${HOSTNAME}" ]; then
      retcode=`ps -ef |grep ${NET_SERVER} |grep -v rsh |grep -v grep |wc -l`
      if [ $retcode -lt 1 ]; then
        /tmp/${NET_SERVER} -p ${NETPERF_PORT} ${m_mode} -${ip_version} > /tmp/netserver.log &
      fi
    else
      retcode=`rsh -n ${host} "ps -ef |grep ${NET_SERVER} |grep -v grep |wc -l"`
      if [ $retcode -lt 1 ]; then
        rsh -n ${host} "/tmp/${NET_SERVER} -p ${NETPERF_PORT} ${m_mode} -${ip_version} > /tmp/netserver.log &" &
        verify_rsh $? ${host}_${NET_SERVER}
      fi
    fi
  done

  sleep 10
  #########################################################################
  # start SESSION_PER_INTERFACE ${NET_PERF} client on all test systems
  # traffic is always bi-directional
  #########################################################################
  TOTAL_SESSION=0; export TOTAL_SESSION
  finish_sess=0; export finish_sess
  i=1
  # loop through client-server pairs
  while [ $i -le $field ]
  do
    svr_host=`echo ${MAXQ_SUT_IF} | cut -f$i -d' '`
    cli_host=`echo ${MAXQ_CLI_IF} | cut -f$i -d' '`
    ###################################
    # on svr_host
    ###################################
    if [ ${MAXQ_TRAFFIC_TYPE} = "tx" -o ${MAXQ_TRAFFIC_TYPE} = "bi" ]
    then
      echo "Connecting from $svr_host -> $cli_host for ${l_sess} sessions..."
      if [ "X${MULTICAST_SUBNET}" != "X" ]; then
        if [ ${sut_os} = "SunOS" ]; then
          mif=`route -n get ${MULTICAST_SUBNET} | grep interface | awk '{print \$2}' | sort`
	  if [ `echo $mif | wc -w` -gt 1 ]; then
	    echo "Warning: Multiple interfaces in ${MULTICAST_SUBNET} subnet."
	    echo "$mif"
	    mif=`echo $mif | awk '{print $1}'`
	    echo "         $mif being picked for multicast"
	  fi
          m_mode=""; export m_mode
        elif [ ${sut_os} = "Linux" ]; then
          mif=`netstat -rn | grep ${MULTICAST_SUBNET} | awk '{print \$8}' | sort`
	  if [ `echo $mif | wc -w` -gt 1 ]; then
	    echo "Warning: Multiple interfaces in ${MULTICAST_SUBNET} subnet."
	    echo "$mif"
	    mif=`echo $mif | awk '{print $1}'`
	    echo "         $mif being picked for multicast"
	  fi
          m_mode=""; export m_mode
        fi
      fi
      # start for SESSION_PER_INTERFACE times
      tmpsess=1
      while [ $tmpsess -le ${l_sess} ]
      do
        if [ ${PROTOCOL_TYPE} = "TCP_STREAM" ] ||
           [ ${PROTOCOL_TYPE} = "UDP_STREAM" ] ||
           [ ${PROTOCOL_TYPE} = "TCPIPV6_STREAM" ] ||
           [ ${PROTOCOL_TYPE} = "UDPIPV6_STREAM" ]; then
          /tmp/${NET_PERF} ${m_mode} -H $cli_host -l $l_timeout \
		-p ${NETPERF_PORT} \
                -t ${PROTOCOL_TYPE} -${ip_version} \
                -- -s $MAXQ_BUF_SIZE -S $MAXQ_BUF_SIZE -m $MAXQ_DATA_SIZE \
                   $tcp_nodelay >/tmp/netperf.sut${TOTAL_SESSION} &
        else
          /tmp/${NET_PERF} ${m_mode} -H $cli_host -l $l_timeout \
		-p ${NETPERF_PORT} \
                -t ${PROTOCOL_TYPE} -${ip_version} \
                -- -s $MAXQ_BUF_SIZE -S $MAXQ_BUF_SIZE -r $MAXQ_DATA_SIZE \
                   $tcp_nodelay >/tmp/netperf.sut${TOTAL_SESSION} &
        fi
        tmpsess=`expr $tmpsess + 1`
        TOTAL_SESSION=`expr ${TOTAL_SESSION} + 1`
      done
    fi

    ###################################
    # on cli_host
    ###################################
    if [ ${MAXQ_TRAFFIC_TYPE} = "rx" -o ${MAXQ_TRAFFIC_TYPE} = "bi" ]
    then
      echo "Connecting from $cli_host -> $svr_host for ${l_sess} sessions..."
      cli_os=""
      cli_os=`rsh -n $cli_host uname -s`
      if [ "X${MULTICAST_SUBNET}" != "X" ]
      then
        if [ "X${cli_os}" = "XSunOS" ]
        then
          mif=`rsh -n $cli_host "route -n get ${MULTICAST_SUBNET}" | grep interface | awk '{print \$2}' | sort`
	  if [ `echo $mif | wc -w` -gt 1 ]; then
	    echo "Warning: Multiple interfaces in ${MULTICAST_SUBNET} subnet."
	    echo "$mif"
	    mif=`echo $mif | awk '{print $1}'`
	    echo "         $mif being picked for multicast"
	  fi
          m_mode=""; export m_mode
        elif [ "X${cli_os}" = "XLinux" ]
        then
          mif=`rsh -n $cli_host netstat -rn | grep ${MULTICAST_SUBNET} | awk '{print \$8}' | sort`
	  if [ `echo $mif | wc -w` -gt 1 ]; then
	    echo "Warning: Multiple interfaces in ${MULTICAST_SUBNET} subnet."
	    echo "$mif"
	    mif=`echo $mif | awk '{print $1}'`
	    echo "         $mif being picked for multicast"
	  fi
          m_mode=""; export m_mode
        else
          echo "get_TP: rsh $cli_host uname -s return ${cli_os}"
	  echo "MAXQ.auto aborted due to rsh failure"
          if [ ${sut_os} = "SunOS" ]; then
            mailx -s "${PRODUCT}: ${TESTNAME} results on ${HOSTNAME}" ${MAILTO} < ${LOGFILE}
          elif [ ${sut_os} = "Linux" ]; then
            mail -s "${PRODUCT}: ${TESTNAME} results on ${HOSTNAME}" ${MAILTO} < ${LOGFILE}
          fi
          exit 1
        fi
      fi
      ####################################################################
      # Use one rsh to start SESSION_PER_INTERFACE sessions
      ####################################################################
      echo "rsh ${cli_host} /tmp/start_netperf.sh ${l_sess} ${svr_host} ${NETPERF_PORT} ${cli_host} ${l_timeout} ${PROTOCOL_TYPE} ${ip_version} ${MAXQ_BUF_SIZE} ${MAXQ_BUF_SIZE} ${MAXQ_DATA_SIZE} ${TOTAL_SESSION} ${MAXQ_TCP_NODELAY} ${m_mode}"

      rsh -n ${cli_host} "/tmp/start_netperf.sh ${l_sess} \
				${svr_host} ${NETPERF_PORT} \
				${cli_host} ${l_timeout} \
				${PROTOCOL_TYPE} ${ip_version} \
				${MAXQ_BUF_SIZE} ${MAXQ_BUF_SIZE} \
				${MAXQ_DATA_SIZE} ${TOTAL_SESSION} \
				${MAXQ_TCP_NODELAY} ${m_mode}" &
      verify_rsh $? ${cli_host}_start_netperf.sh
      TOTAL_SESSION=`expr ${TOTAL_SESSION} + ${l_sess}`
    fi

    i=`expr $i + 1`
  done

  # send multicast to start TX|RX
  if [ "X${MULTICAST_SUBNET}" != "X" ]; then
    # wait for a while to make sure all connections are established
    echo "Waiting for ${TOTAL_SESSION} connections to establish..."
    if [ ${TOTAL_SESSION} -gt 500 ]; then
      sleep `expr ${TOTAL_SESSION} / 15`
    else
      sleep 30
    fi
    if [ ${stop_on_error} -ne 0 ]
    then
      TXPROCS=`ps -ef | grep ${NET_PERF} | grep -v grep | wc -l`
      echo "$TXPROCS TX procs"
      RXPROCS=`ps -ef | grep ${NET_SERVER} | grep -v grep | grep -v rsh | wc -l`
      echo "       `expr $RXPROCS - 1` RX procs"
    fi
    echo "`date`:multicast fired on subnet ${MULTICAST_SUBNET}\n"

  fi

  # wait for 30 more extra seconds so all test can finish if not hang
  sleep `expr ${l_timeout} + 30`

  if [ "X${MULTICAST_SUBNET}" = "X" ]; then
    TIMEWAIT=0
    while [ `ps -ef | grep ${NET_PERF} | grep -v grep | wc -l` -gt 0 ]
    do
      sleep 60
      TIMEWAIT=`expr ${TIMEWAIT} + 60`
      echo "waitted for extra ${TIMEWAIT} seconds"
    done
  fi

  # collect performance logs
  touch /tmp/netperf.sut /tmp/netperf.cnt /tmp/netperf.summary

  if [ "X${MAXQ_TRAFFIC_TYPE}"  != "Xrx" ]
  then
    cat /tmp/netperf.sut?* > /tmp/netperf.sut
  fi

  for host in ${MAXQ_CLIENT}
  do
      	cli_wait=`rsh -n ${host} "ls -l /tmp/netperf.${host}.cnt?*" | \
		awk '{x+=$5}END{printf"%d",x}'`
      	# Wait for the client's results, sometimes client is slow 
      	if [ $cli_wait -eq 0 ]; then
      		echo "waiting 60 seconds for client results"
      		sleep 60
      	fi
      if [ "X${MAXQ_TRAFFIC_TYPE}"  != "Xtx" ]; then
          rsh -n ${host} "cat /tmp/netperf.${host}.cnt?*" >> /tmp/netperf.cnt
          verify_rsh $?
      fi

  done

  sleep 1
  cat /tmp/netperf.sut /tmp/netperf.cnt > /tmp/netperf.summary
  sleep 2

  # calculate the perf number
  if [ ${MAXQ_TYPE} -ne 0 ]; then
    get_throughput /tmp/netperf.summary
    finish_sess=`awk '$5~/^[0-9]*\.[0-9]*$/{x+=1}END{printf("%.0f",x)} ' \
                    /tmp/netperf.summary`
    if [ ${TOTAL_SESSION} -ne ${finish_sess} ]; then
      echo "Finished ${finish_sess} out of ${TOTAL_SESSION} sessions: failed" \
            >>${LOGFILE}
      echo "with $1 card and total ${TOTAL_SESSION} sessions" \
            >>${LOGFILE}
      echo "------------------------------------------------"
      echo "print all of netperf log on ${MAXQ_CLIENT}"
      cat /tmp/netperf.cnt	
      echo "------------------------------------------------"
      echo "print all of netperf log on ${MAXQ_SUT_IF}"
      cat /tmp/netperf.sut
      echo "------------------------------------------------"

	
      if [ ${stop_on_error} -ne 0 ]
      then
        echo "*** press -RETURN- to continue ***"
        echo ""
        read x
      fi
    fi
  fi
}

###############################################################################
# routine to collect maxQ, systemQ, connectQ use sequential algorithm,
# because the experiments show the best performance is always happens when 
# session per interface is less than 8. When session per interface increases
# the performance drops.
#
# usage: run_maxq_seq numcards
#
# MAXQ Theory:
#   1. measure single card maximum performance by stepping through different
#      number of sessions. MAX_Q number set to 1
#   2. use single card maximum performance as MAXQ base, then adding additional
#      cards. If maximum performance increases linearly as card number 
#      increases, MAX_Q number set to the new number of cards; otherwise, 
#      MAX_Q number does not change
#   3. while number of cards increases, if total performance increases, then
#      SYSTEM_Q and CONNECTIVITY_Q increase too
#   4. when number of card increase to certain number, total performance
#      starts to drop. SYSTEM_Q set to the card number with maximum system
#      total performance. While total performance drops but still greater
#      than MAX_Q performance, CONNECTIVITY_Q number still increase
#   5. after certain point, total system performance drops below MAX_Q
#      performance, set CONNECTIVITY_Q to the number of cards where total
#      system performance is just greater or equal to MAX_Q performance
###############################################################################
run_maxq_seq()
{
  #set -x

  # following vars are for performance/sessions tracking purpose
  base_TP=0                         # for MAX TP
  base_ss=0                         # session number for MAX TP
  min_TP=0                          # for future use
  cur_TP=0                          # current run performance

  maxq_base_TP=0                    # single card maxq performance
  maxq_base_ss=0                    # session number of maxq_base_TP
  maxq_reduced_base_TP=0            # 95% maxq_base_TP

  # track single session perf, on some systems single session per card
  # perf is so bad that could cause the maxq algorithm to stop
  one_perf=0			    # single session perf per card

  # loop through number of cards
  card=1
  while [ $card -le $1 ]
  do
    if [ ${sut_os} = "SunOS" ]; then
      echo "Card\tSess/\tPort/\tTotal\tThroughput" >/tmp/$TESTNAME/history.$card
      echo "    \tPort \tCard \tSess \t          " >>/tmp/$TESTNAME/history.$card
      echo "====\t=====\t=====\t=====\t==========" >>/tmp/$TESTNAME/history.$card
    elif [ ${sut_os} = "Linux" ]; then
      echo -e "Card\tSess/\tPort/\tTotal\tThroughput" >/tmp/$TESTNAME/history.$card
      echo -e "    \tPort \tCard \tSess \t          " >>/tmp/$TESTNAME/history.$card
      echo -e "====\t=====\t=====\t=====\t==========" >>/tmp/$TESTNAME/history.$card
    fi

    # limit maximum sessions to 500, otherwise system will hit rsh limit
    MAXSESSION=`expr $max_session / $INTERFACE_PER_CARD / $card`
    export MAXSESSION

    # loop through number of sessions, max sess set to MAXSESSION
    sess=1
    while [ $sess -lt ${MAXSESSION} ]
    do
      get_TP $card $sess $timeout_short
      cur_TP=${total_tp}
      # set first value to min_TP
      if [ $min_TP -eq 0 ]; then
        min_TP=$cur_TP
      fi

      # if it's single session and greater than previous one, update
      if [ $sess -eq 1 ]; then
        if [ $cur_TP -gt $one_perf ]; then
          one_perf=$cur_TP
        else
          echo "$card: single session perf dropping below previous"
        fi
      fi

      # calculate total number of sessions
      tss=`expr $sess \* $card \* $INTERFACE_PER_CARD \* 2`
      if [ ${sut_os} = "SunOS" ]; then
        echo "$card\t$sess\t$INTERFACE_PER_CARD\t$tss\t$cur_TP" >>/tmp/$TESTNAME/history.$card
      elif [ ${sut_os} = "Linux" ]; then
        echo -e "$card\t$sess\t$INTERFACE_PER_CARD\t$tss\t$cur_TP" >>/tmp/$TESTNAME/history.$card
      fi

      # update base_TP to maximum performance value
      if [ $cur_TP -gt $base_TP ]; then
        base_TP=$cur_TP
        base_ss=$sess
      fi

      # update min_TP to minimum performance value
      if [ $cur_TP -lt $min_TP ]; then
        min_TP=$cur_TP
      fi

      # update connect Q info
      if [ $cur_TP -ge $maxq_perf_tp -a $card -gt 1 ]; then
	if [ $cur_TP -gt $connectivity_tp ]; then
	  connectivity_tp=$cur_TP
          connectivity_ss=$sess      
          connectivity_cards=$card
	fi
      fi

      # save the session number for maxq sustaining run purpose
      # when cur_TP in 5% swing range
      if [ $maxq_base_TP -ne 0 ]; then
        if [ $cur_TP -gt `expr $maxq_reduced_base_TP \* $card` -a \
             $cur_TP -lt `expr $maxq_base_TP \* $card` ]; then 
          maxq_base_ss=$sess
        fi
      fi

      # terminate sess loop if cur_TP below accepted range and
      # it is not a single session per card perf
      if [ $cur_TP -lt `expr $base_TP \* $stop_flag / 100` ]; then
        if [ $sess -ne 1 ]; then
          sess=${MAXSESSION}
        fi
      fi
      cleanup	# workaround for sync_server not going away

      # need make decision on sampling methods
      # based on experimental run, TP tends to increase if session<10
      # TP tends stablized or drop when session > 10
      # thus we take more samples from 1-10 and less after 10
      if [ $sess -eq 1 ]; then
        sess=`expr $sess + 1`
      elif [ $sess -lt 16 ]; then
        sess=`expr $sess + 2`
      else
        sess=`expr $sess + 8`
      fi
    done
 
    # record the single card maxq_base_TP
    if [ $card -eq 1 ]; then
      maxq_perf_cards=1
      maxq_perf_tp=$base_TP
      maxq_perf_ss=$base_ss
      system_cards=1
      system_tp=$maxq_perf_tp
      system_ss=$maxq_perf_ss
      connectivity_cards=1
      connectivity_tp=$maxq_perf_tp
      connectivity_ss=$maxq_perf_ss
      maxq_base_TP=$maxq_perf_tp
      maxq_base_ss=$base_ss
      # calculate maxq_reduced_base_TP (5% lower)
      maxq_reduced_base_TP=`expr $maxq_perf_tp \* $deviation / 100`
    else   # multiple cards
      # tmp_TP is maxq_reduced_base_TP multiply by number of cards
      tmp_TP=`expr $maxq_reduced_base_TP \* $card`
      # calculate new MAX_Q
      if [ $base_TP -ge $tmp_TP ]; then
        if [ $base_TP -ge $maxq_perf_tp ]; then
          maxq_perf_tp=$maxq_perf_tp
        else
          maxq_perf_tp=$tmp_TP
        fi
        maxq_perf_cards=$card
        maxq_perf_ss=$maxq_base_ss
      fi

      # calculate SYSTEM_Q & CONNECTIVITY_Q
      if [ $base_TP -gt $system_tp ]
      then
        system_cards=$card
        system_tp=$base_TP
        system_ss=$base_ss
      fi
    fi

    # calculate SUSTAIN throughtput when all card being tested
    if [ $card -eq $1 ]; then
        # sustained MAX_Q
        mpstat 30 >/tmp/$TESTNAME/mpstat.MAX_Q &
	if [ ${sut_os} = "SunOS" ]; then
          echo "Before ${NET_PERF} run" > /tmp/$TESTNAME/kstat.MAX_Q
          kstat -m $PRODUCT >>/tmp/$TESTNAME/kstat.MAX_Q
	fi
        get_TP $maxq_perf_cards $maxq_perf_ss $timeout_sustain
        maxq_tp_sustain=${total_tp}
	if [ ${sut_os} = "SunOS" ]; then
          echo "After ${NET_PERF} run" >> /tmp/$TESTNAME/kstat.MAX_Q
          kstat -m $PRODUCT >>/tmp/$TESTNAME/kstat.MAX_Q
	fi
        tss=`expr $maxq_perf_ss \* $maxq_perf_cards \* $INTERFACE_PER_CARD \* 2`
        if [ ${sut_os} = "SunOS" ]; then
          echo "$maxq_perf_cards\t$maxq_perf_ss\t$INTERFACE_PER_CARD\t$tss\t$maxq_tp_sustain\tMAXQ_TP_SUSTAIN" >>/tmp/$TESTNAME/history.$maxq_perf_cards
        elif [ ${sut_os} = "Linux" ]; then
          echo -e "$maxq_perf_cards\t$maxq_perf_ss\t$INTERFACE_PER_CARD\t$tss\t$maxq_tp_sustain\tMAXQ_TP_SUSTAIN" >>/tmp/$TESTNAME/history.$maxq_perf_cards
        fi
        cleanup   # workaround for sync_server not going away

        # sustained SYSTEM_Q
	# Skip sustaining run if SYSTEM_Q = MAX_Q
	if [ $maxq_perf_cards -eq $system_cards ]
	then
          if [ ${sut_os} = "SunOS" ]; then
            echo "$maxq_perf_cards\t$maxq_perf_ss\t$INTERFACE_PER_CARD\t$tss\t$maxq_tp_sustain\tSYSTEMQ_TP_SUSTAIN" >>/tmp/$TESTNAME/history.$maxq_perf_cards
          elif [ ${sut_os} = "Linux" ]; then
            echo -e "$maxq_perf_cards\t$maxq_perf_ss\t$INTERFACE_PER_CARD\t$tss\t$maxq_tp_sustain\tSYSTEMQ_TP_SUSTAIN" >>/tmp/$TESTNAME/history.$maxq_perf_cards
          fi
	else
	  mpstat 30 >/tmp/$TESTNAME/mpstat.SYSTEM_Q &
	  if [ ${sut_os} = "SunOS" ]; then
            echo "Before ${NET_PERF} run" > /tmp/$TESTNAME/kstat.SYSTEM_Q
            kstat -m $PRODUCT >>/tmp/$TESTNAME/kstat.SYSTEM_Q
	  fi
          get_TP $system_cards $system_ss $timeout_sustain
          system_tp_sustain=${total_tp}
	  if [ ${sut_os} = "SunOS" ]; then
            echo "After ${NET_PERF} run" >> /tmp/$TESTNAME/kstat.SYSTEM_Q
            kstat -m $PRODUCT >>/tmp/$TESTNAME/kstat.SYSTEM_Q
	  fi
          tss=`expr $system_ss \* $system_cards \* $INTERFACE_PER_CARD \* 2`
          if [ ${sut_os} = "SunOS" ]; then
            echo "$system_cards\t$system_ss\t$INTERFACE_PER_CARD\t$tss\t$system_tp_sustain\tSYSTEMQ_TP_SUSTAIN" >>/tmp/$TESTNAME/history.$system_cards
          elif [ ${sut_os} = "Linux" ]; then
            echo -e "$system_cards\t$system_ss\t$INTERFACE_PER_CARD\t$tss\t$system_tp_sustain\tSYSTEMQ_TP_SUSTAIN" >>/tmp/$TESTNAME/history.$system_cards
          fi
          cleanup   # workaround for sync_server not going away
	fi
        # sustained CONNECTIVITY_Q
	# Skip sustaining run if CONNECT_Q = MAX_Q or SYSTEM_Q
	if [ $maxq_perf_cards -eq $connectivity_cards ]
	then
          if [ ${sut_os} = "SunOS" ]; then
            echo "$maxq_perf_cards\t$maxq_perf_ss\t$INTERFACE_PER_CARD\t$tss\t$maxq_tp_sustain\tCONNECTQ_TP_SUSTAIN" >>/tmp/$TESTNAME/history.$maxq_perf_cards
          elif [ ${sut_os} = "Linux" ]; then
            echo -e "$maxq_perf_cards\t$maxq_perf_ss\t$INTERFACE_PER_CARD\t$tss\t$maxq_tp_sustain\tCONNECTQ_TP_SUSTAIN" >>/tmp/$TESTNAME/history.$maxq_perf_cards
          fi
	elif [ $system_cards -eq $connectivity_cards ]
	then
          if [ ${sut_os} = "SunOS" ]; then
            echo "$system_cards\t$system_ss\t$INTERFACE_PER_CARD\t$tss\t$system_tp_sustain\tCONNECTQ_TP_SUSTAIN" >>/tmp/$TESTNAME/history.$system_cards
          elif [ ${sut_os} = "Linux" ]; then
            echo -e "$system_cards\t$system_ss\t$INTERFACE_PER_CARD\t$tss\t$system_tp_sustain\tCONNECTQ_TP_SUSTAIN" >>/tmp/$TESTNAME/history.$system_cards
          fi
	else
          mpstat 30 >/tmp/$TESTNAME/mpstat.CONNECTIVITY_Q &
	  if [ ${sut_os} = "SunOS" ]; then
            echo "Before ${NET_PERF} run" > /tmp/$TESTNAME/kstat.CONNECTIVITY_Q
            kstat -m $PRODUCT >>/tmp/$TESTNAME/kstat.CONNECTIVITY_Q
	  fi
          get_TP $connectivity_cards $connectivity_ss $timeout_sustain
          connectivity_tp_sustain=${total_tp}
	  if [ ${sut_os} = "SunOS" ]; then
            echo "After ${NET_PERF} run" >> /tmp/$TESTNAME/kstat.CONNECTIVITY_Q
            kstat -m $PRODUCT >>/tmp/$TESTNAME/kstat.CONNECTIVITY_Q
	  fi
          tss=`expr $connectivity_ss \* $connectivity_cards \* $INTERFACE_PER_CARD \* 2`
          if [ ${sut_os} = "SunOS" ]; then
            echo "$connectivity_cards\t$connectivity_ss\t$INTERFACE_PER_CARD\t$tss\t$connectivity_tp_sustain\tCONNECTQ_TP_SUSTAIN" >>/tmp/$TESTNAME/history.$connectivity_cards
          elif [ ${sut_os} = "Linux" ]; then
            echo -e "$connectivity_cards\t$connectivity_ss\t$INTERFACE_PER_CARD\t$tss\t$connectivity_tp_sustain\tCONNECTQ_TP_SUSTAIN" >>/tmp/$TESTNAME/history.$connectivity_cards
          fi
          cleanup   # workaround for sync_server not going away
	fi
    fi
    card=`expr $card + 1`
    connectivity_tp=0
  done
  return 0
}

###############################################################################
# routine to report SUT info
###############################################################################
report_system()
{
  if [ "X${MULTICAST_SUBNET}" = "X" ]; then
    echo "##############################################################"
    echo "# NOT SYNCHRONIZED RUN, DO NOT REPORT AS PERFORMACE NUMBERS  #"
    echo "##############################################################"
    echo ""
  fi

  if [ ${MAXQ_TYPE} = "1" ]; then
    echo "MAXQ reporting..."
  else
    echo "Throughput reporting..."
  fi
  echo ""
  echo "Test Date: $starttime"
  echo ""
  echo "========================= SUT info ========================= "
  uname -a
  # SUT information
  host_os=`uname -s`
  if [ ${host_os} = "SunOS" ]; then
    modinfo | grep " $PRODUCT "
    if [ "X${MULTICAST_SUBNET}" != "X" ]; then
      echo ""
      echo "================Begin /etc/system ========================= "
      awk '/^[ \ta-z]/ {print $0}' /etc/system
      echo "==================End /etc/system ========================= "
    fi
  elif [ ${host_os} = "Linux" ]; then
    echo "CPU:"
    dmesg | grep -i cpu | grep -i [g\|m]hz
    dmesg | grep -i cpu[0-9]
    echo ""
    echo "MEMORY/SWAP:"
    free
  fi

}

###############################################################################
# routine to report error and generate final single perf report
# usage: report_TP 
###############################################################################
report_TP()
{
  #set -x

  STATUS=0
  finish_sess=0; export finish_sess
  for i in $*
  do
    grep -i -w $i ${LOGFILE}
    if [ $? -eq 0 ]          # pattern found, flag error
    then
      STATUS=`expr $STATUS + 1`
    fi
    grep -i -w $i /tmp/netperf.summary
    if [ $? -eq 0 ]          # pattern found, flag error
    then
      STATUS=`expr $STATUS + 1`
    fi
  done

  echo ""
  echo "        SUMMARY:"
  echo "================================================="
  echo "SUT          :        ${MAXQ_SUT_IF}"
  echo "CLIENTS      :        ${MAXQ_CLI_IF}"
  echo "SOCKET_BUFFER:        ${MAXQ_BUF_SIZE}"
  echo "MESSAGE_SIZE :        ${MAXQ_DATA_SIZE}"
  echo "PROTOCOL_TYPE:        ${PROTOCOL_TYPE}"
  echo "TCP_NODELAY  :        ${MAXQ_TCP_NODELAY}"
  echo "TRAFFIC_TYPE :        ${MAXQ_TRAFFIC_TYPE}"
  echo "# OF CARDS   :        ${numcards}"
  echo "PORT PER CARD:        ${INTERFACE_PER_CARD}"
  echo "TOTAL_SESSION:        ${TOTAL_SESSION}"
  echo "timeout_short:        ${timeout_short}"

  case ${PROTOCOL_TYPE} in
    TCP_STREAM)
        t_sut=`awk '$5~/^[0-9]*\.[0-9]*$/{x+=$5}END{printf("%.2f",x)} ' \
               /tmp/netperf.sut`
        r_sut=`awk '$5~/^[0-9]*\.[0-9]*$/{x+=$5}END{printf("%.2f",x)} ' \
               /tmp/netperf.cnt`
        tx_rx=`awk '$5~/^[0-9]*\.[0-9]*$/{x+=$5}END{printf("%.2f",x)} ' \
               /tmp/netperf.summary`
        finish_sess=`awk '$5~/^[0-9]*\.[0-9]*$/{x+=1}END{printf("%.0f",x)} ' \
               /tmp/netperf.summary`
        echo "THROUGH_PUT TCP TX :        ${t_sut} mbits/s"
        echo "                RX :        ${r_sut} mbits/s"
        echo "                BI :        ${tx_rx} mbits/s"
        ;;
    UDP_STREAM)
        t_sut=`awk '$6~/^[0-9]*\.[0-9]*$/{x+=$6}END{printf("%.2f",x)} ' \
               /tmp/netperf.sut`
        r_sut=`awk '$4~/^[0-9]*\.[0-9]*$/{x+=$4}END{printf("%.2f",x)} ' \
               /tmp/netperf.cnt`
        echo "$t_sut" >/tmp/netperf.sum
        echo "$r_sut" >>/tmp/netperf.sum
        tx_rx=`awk '$1~/^[0-9]*\.[0-9]*$/{x+=$1}END{printf("%.2f",x)} ' \
               /tmp/netperf.sum`
        rm -f /tmp/netperf.sum
        finish_sess=`awk '$6~/^[0-9]*\.[0-9]*$/{x+=1}END{printf("%.0f",x)} ' \
                     /tmp/netperf.summary`
        echo "THROUGH_PUT UDP TX :        ${t_sut}"
        echo "                RX :        ${r_sut}"
        echo "                BI :        ${tx_rx} mbits/s"
        ;;
    TCP_RR)
       t_sut=`awk '$6~/^[0-9]*\.[0-9]*$/{x+=$6}END{printf("%.2f",x)} ' \
              /tmp/netperf.summary`
       finish_sess=`awk '$6~/^[0-9]*\.[0-9]*$/{x+=1}END{printf("%.0f",x)} ' \
                    /tmp/netperf.summary`
       echo "TCP Request/Response:        ${t_sut} Trans Rate/s"
       ;;
    UDP_RR)
       t_sut=`awk '$6~/^[0-9]*\.[0-9]*$/{x+=$6}END{printf("%.2f",x)} ' \
              /tmp/netperf.summary`
       finish_sess=`awk '$6~/^[0-9]*\.[0-9]*$/{x+=1}END{printf("%.0f",x)} ' \
                    /tmp/netperf.summary`
       echo "UDP Request/Response:        ${t_sut} Trans Rate/s"
       ;;
    TCP_CRR)
       t_sut=`awk '$6~/^[0-9]*\.[0-9]*$/{x+=$6}END{printf("%.2f",x)} ' \
              /tmp/netperf.summary`
       finish_sess=`awk '$6~/^[0-9]*\.[0-9]*$/{x+=1}END{printf("%.0f",x)} ' \
                    /tmp/netperf.summary`
       echo "TCP Connect/Request/Response:        ${t_sut} Trans Rate/s"
       ;;
    TCPIPV6_STREAM)
       t_sut=`awk '$5~/^[0-9]*\.[0-9]*$/{x+=$5}END{printf("%.2f",x)} ' \
              /tmp/netperf.sut`
       r_sut=`awk '$5~/^[0-9]*\.[0-9]*$/{x+=$5}END{printf("%.2f",x)} ' \
              /tmp/netperf.cnt`
       tx_rx=`awk '$5~/^[0-9]*\.[0-9]*$/{x+=$5}END{printf("%.2f",x)} ' \
              /tmp/netperf.summary`
       finish_sess=`awk '$5~/^[0-9]*\.[0-9]*$/{x+=1}END{printf("%.0f",x)} ' \
                    /tmp/netperf.summary`
       echo "THROUGH_PUT TCP TX :        ${t_sut} mbits/s"
       echo "                RX :        ${r_sut} mbits/s"
       echo "                BI :        ${tx_rx} mbits/s"
       ;;
    UDPIPV6_STREAM)
       t_sut=`awk '$6~/^[0-9]*\.[0-9]*$/{x+=$6}END{printf("%.2f",x)} ' \
              /tmp/netperf.sut`
       r_sut=`awk '$4~/^[0-9]*\.[0-9]*$/{x+=$4}END{printf("%.2f",x)} ' \
              /tmp/netperf.cnt`
       echo "$t_sut" >/tmp/netperf.sum
       echo "$r_sut" >>/tmp/netperf.sum
       tx_rx=`awk '$1~/^[0-9]*\.[0-9]*$/{x+=$1}END{printf("%.2f",x)} ' \
              /tmp/netperf.sum`
       rm -f /tmp/netperf.sum
       finish_sess=`awk '$6~/^[0-9]*\.[0-9]*$/{x+=1}END{printf("%.0f",x)} ' \
                    /tmp/netperf.summary`
       echo "THROUGH_PUT UDP TX :        ${t_sut}"
       echo "                RX :        ${r_sut}"
       echo "                BI :        ${tx_rx} mbits/s"
       ;;
    TCPIPV6_RR)
       t_sut=`awk '$6~/^[0-9]*\.[0-9]*$/{x+=$6}END{printf("%.2f",x)} ' \
              /tmp/netperf.summary`
       finish_sess=`awk '$6~/^[0-9]*\.[0-9]*$/{x+=1}END{printf("%.0f",x)} ' \
                    /tmp/netperf.summary`
       echo "TCP Request/Response:        ${t_sut} Trans Rate/s"
       ;;
    UDPIPV6_RR)
       t_sut=`awk '$6~/^[0-9]*\.[0-9]*$/{x+=$6}END{printf("%.2f",x)} ' \
              /tmp/netperf.summary`
       finish_sess=`awk '$6~/^[0-9]*\.[0-9]*$/{x+=1}END{printf("%.0f",x)} ' \
                    /tmp/netperf.summary`
       echo "UDP Request/Response:        ${t_sut} Trans Rate/s"
       ;;
    TCPIPV6_CRR)
       t_sut=`awk '$6~/^[0-9]*\.[0-9]*$/{x+=$6}END{printf("%.2f",x)} ' \
              /tmp/netperf.summary`
       finish_sess=`awk '$6~/^[0-9]*\.[0-9]*$/{x+=1}END{printf("%.0f",x)} ' \
                    /tmp/netperf.summary`
       echo "TCP Connect/Request/Response:        ${t_sut} Trans Rate/s"
       ;;
  esac

  if [ ${TOTAL_SESSION} -ne ${finish_sess} ]; then
    echo "Finished ${finish_sess} out of ${TOTAL_SESSION} sessions: failed" 
    STATUS=`expr $STATUS + 1`

    echo "------------------------------------------------"
    echo "print all of netperf log on ${MAXQ_CLIENT}"
    cat /tmp/netperf.cnt	
    echo "------------------------------------------------"
    echo "print all of netperf log on ${MAXQ_SUT_IF}"
    cat /tmp/netperf.sut
    echo "------------------------------------------------"

    if [ ${stop_on_error} -ne 0 ]
    then
        echo "*** press -RETURN- to continue ***"
	echo ""
	read x
    fi
  fi

  echo ""
  echo ""

  # checking final status
  if [ $STATUS -gt 0 ]
  then
    echo "======== ${TESTNAME} _STATUS_ ========:                _FAILED_"
    echo " Please review"
    echo " ${LOGDIR}/`basename ${LOGFILE}`, thanks"
  else
    echo "======== ${TESTNAME} _STATUS_ ========:                _PASSED_"
  fi

  echo "Finish time: `date`"
  echo ""
  if [ "X${MULTICAST_SUBNET}" = "X" ]; then
    echo "##############################################################"
    echo "# NOT SYNCHRONIZED RUN, DO NOT REPORT AS PERFORMACE NUMBERS  #"
    echo "##############################################################"
    echo ""
  fi
}

###############################################################################
# routine to report error and generate final maxq report
# usage: report 
###############################################################################
report_maxq()
{
  #set -x

  echo ""
  echo "MAXQ use:"
  echo "SOCKET_BUFFER:        ${MAXQ_BUF_SIZE}"
  echo "MESSAGE_SIZE :        ${MAXQ_DATA_SIZE}"
  echo "TCP_NODELAY  :        ${MAXQ_TCP_NODELAY}"
  echo "timeout_short:        ${timeout_short}"
  echo "timeout_sustain:      ${timeout_sustain}"
  echo "deviation    :        ${deviation}%"
  echo "stop at      :        ${stop_flag}%"
  echo ""
  card_idx=1
  while [ $card_idx -le $numcards ]
  do
    echo ""
    echo "Throughput for $card_idx card:"
    cat /tmp/$TESTNAME/history.$card_idx
    echo ""
    card_idx=`expr $card_idx + 1`
  done

  echo ""
  echo "        SUMMARY:"
  echo ""
  echo ""
  if [ ${sut_os} = "SunOS" ]; then
    echo "Q-type\tcard\tperf\tse/p\tsustain_perf"
    echo "======\t====\t====\t====\t============"
    echo "MAX_Q \t$maxq_perf_cards\t$maxq_perf_tp\t$maxq_perf_ss\t$maxq_tp_sustain"
    # MAX_Q = SYS_Q
    if [ $maxq_perf_cards -eq $system_cards ]; then
      echo "SYS_Q \t$maxq_perf_cards\t$maxq_perf_tp\t$maxq_perf_ss\t$maxq_tp_sustain"
    else
      echo "SYS_Q \t$system_cards\t$system_tp\t$system_ss\t$system_tp_sustain"
    fi
    # CON_Q = MAX_Q
    if [ $connectivity_cards -eq $maxq_perf_cards ]; then
      echo "CON_Q \t$maxq_perf_cards\t$maxq_perf_tp\t$maxq_perf_ss\t$maxq_tp_sustain"
    # CON_Q = SYS_Q
    elif [ $connectivity_cards -eq $system_cards ]; then
      echo "CON_Q \t$system_cards\t$system_tp\t$system_ss\t$system_tp_sustain"
    else
      echo "CON_Q \t$connectivity_cards\t$connectivity_tp\t$connectivity_ss\t$connectivity_tp_sustain"
    fi
  elif [ ${sut_os} = "Linux" ]; then
    echo -e "Q-type\tcard\tperf\tse/p\tsustain_perf"
    echo -e "======\t====\t====\t====\t============"
    echo -e "MAX_Q \t$maxq_perf_cards\t$maxq_perf_tp\t$maxq_perf_ss\t$maxq_tp_sustain"
    # MAX_Q = SYS_Q
    if [ $maxq_perf_cards -eq $system_cards ]; then
      echo -e "SYS_Q \t$maxq_perf_cards\t$maxq_perf_tp\t$maxq_perf_ss\t$maxq_tp_sustain"
    else
      echo -e "SYS_Q \t$system_cards\t$system_tp\t$system_ss\t$system_tp_sustain"
    fi
    # CON_Q = MAX_Q
    if [ $connectivity_cards -eq $maxq_perf_cards ]; then
      echo -e "CON_Q \t$maxq_perf_cards\t$maxq_perf_tp\t$maxq_perf_ss\t$maxq_tp_sustain"
    # CON_Q = SYS_Q
    elif [ $connectivity_cards -eq $system_cards ]; then
      echo -e "CON_Q \t$system_cards\t$system_tp\t$system_ss\t$system_tp_sustain"
    else
      echo -e "CON_Q \t$connectivity_cards\t$connectivity_tp\t$connectivity_ss\t$connectivity_tp_sustain"
    fi
  fi
  echo ""
  echo "Total Card:	$numcards"
  echo ""

  # check if any "failed" msg logged
  STATUS=0
  grep -i -w failed ${LOGFILE}
  if [ $? -eq 0 ]          # pattern found, flag error
  then
    STATUS=`expr $STATUS + 1`
  fi

  # checking final status
  if [ $STATUS -gt 0 ]
  then
    echo "======== ${TESTNAME} _STATUS_ ========:                _FAILED_"
    echo " Please review"
    echo " ${LOGDIR}/`basename ${LOGFILE}`, thanks"
  else
    echo "======== ${TESTNAME} _STATUS_ ========:                _PASSED_"
  fi

  echo "Finish time: `date`"
  echo ""
  if [ "X${MULTICAST_SUBNET}" = "X" ]; then
    echo "##############################################################"
    echo "# NOT SYNCHRONIZED RUN, DO NOT REPORT AS PERFORMACE NUMBERS  #"
    echo "##############################################################"
    echo ""
  fi
}

#################################################################################
# cleanup routine to make sure all sessions are finished
# usage: cleanup
#################################################################################
cleanup()
{
  #set -x

  # kill ${NET_SERVER} process/tmp files on local and remote hosts
  for host in $MAXQ_CLIENT
  do
    if [ ${stop_on_error} -eq 0 ]
    then
      if [ ${MAXQ_TYPE} -ne 0 ]
      then
        rsh -n ${host} "pkill -9 ${NET_SERVER}; \
               pkill -9 ${NET_PERF}; \
               rm -f /tmp/netperf.*"
      else
        rsh -n ${host} "pkill -9 ${NET_SERVER}; \
               pkill -9 ${NET_PERF}; \
               rm -f /tmp/start_netperf.sh; \
               rm -f /tmp/netperf.*"
      fi
    else
      if [ ${MAXQ_TYPE} -ne 0 ]
      then
        rsh -n ${host} "pkill -9 ${NET_SERVER}; \
               pkill -9 ${NET_PERF}; \
               rm -f /tmp/netperf.*"
      fi
    fi  
    verify_rsh $? ${host}_pkill
  done

  pkill -9 mpstat
  pkill -9 ${NET_SERVER}
  pkill -9 ${NET_PERF}
  rm -f /tmp/start_netperf.sh
  if [ ${stop_on_error} -eq 0 -o ${MAXQ_TYPE} -ne 0 ]
  then
    rm -f /tmp/netperf.*
  fi

  # make sure all addresses are freed up before next run
  # Somehow linux yp process is always in TIME_WAIT state, so workaround
  # needed for some linux problems(could be a linux bug - not sure
  if [ ${sut_os} = "SunOS" ]; then
    while [ `netstat -a | grep TIME_WAIT | wc -l` -gt 5 ]
    do
      sleep 10
    done
  else
    sleep 30
  fi
  sleep 30
}

#################################################################################
# main
#################################################################################
PROG=`basename $0`
TESTNAME=`basename $0 .auto`; export TESTNAME
LOGFILE=/tmp/$TESTNAME/${TESTNAME}.log.`date '+%y.%m.%d.%H.%M.%S'`; export LOGFILE
HOSTNAME=`uname -n`; export HOSTNAME
rm -rf /tmp/$TESTNAME
rm -f  /tmp/netperf.*
mkdir -p /tmp/$TESTNAME

NET_PERF=netperf
NET_SERVER=netserver
check_netperf
# default values for test goes here
MAILTO=${MAILTO:-"root@$HOSTNAME"}; export MAILTO
LOGDIR=${LOGDIR:-/${STF_RESULTS}/tmp/${TESTNAME}}; export LOGDIR
MAXQ_BUF_SIZE=${MAXQ_BUF_SIZE:-65535}; export MAXQ_BUF_SIZE
MAXQ_DATA_SIZE=${MAXQ_DATA_SIZE:-65535}; export MAXQ_DATA_SIZE
MAXQ_TCP_NODELAY=${MAXQ_TCP_NODELAY:-0}; export MAXQ_TCP_NODELAY
MAXQ_TYPE=${MAXQ_TYPE:-1}; export MAXQ_TYPE
MULTICAST_SUBNET=${MULTICAST_SUBNET:-""}; export MULTICAST_SUBNET
PROTOCOL_TYPE=${PROTOCOL_TYPE:-"TCP_STREAM"}; export PROTOCOL_TYPE
NETPERF_PORT=${NETPERF_PORT:-12865}; export NETPERF_PORT
TEST_MATRIX_ID=${TEST_MATRIX_ID:-""}; export TEST_MATRIX_ID

# timeout_short(5 min) for peak TP & timeout_sustain(8 hrs) for sustaining TP
timeout_short=${timeout_short:-180}; export timeout_short
timeout_sustain=${timeout_sustain:-180}; export timeout_sustain
# Dynamic TP deviation < 5% each run(100-5=95)
deviation=${deviation:-95}; export deviation
ip_version=${ip_version:-4}; export ip_version
max_session=${max_session:-248}; export max_session
stop_on_error=${stop_on_error:-0}; export stop_on_error
STATUS=0; export STATUS

# initialize maxq measurement related vars to 0
maxq_perf_cards=0
maxq_perf_tp=0
maxq_perf_ss=0
maxq_tp_sustain=0
system_cards=0
system_ss=0
system_tp=0
system_tp_sustain=0
connectivity_cards=0
connectivity_tp=0
connectivity_ss=0
stop_flag=85
tcp_time_wait_interval=15000
total_tp=0; export total_tp


starttime=`date`
sut_os=`uname -s`; export sut_os

trap "echo MAXQ killed; pkill netperf; pkill netserver; exit 1" 1 2 3 9 15

# Verify envrionment setup
rm -f ${LOGFILE}
setup $*

if [ -n $MAXQ_RUN_TIME ]
then
	timeout_short=$MAXQ_RUN_TIME; export timeout_short
fi

if [ $? -ne 0 ]
then
  echo "setup: FAILED:"
  exit 1
fi

# cleanup on client if a previously partial run
for host in $MAXQ_CLIENT
do
  rm -f  /tmp/netperf.*
done

# get numcards (number of cards installed in SUT)
num_interface=`echo $MAXQ_SUT_IF | awk '{print NF}'`
numcards=`expr $num_interface / $INTERFACE_PER_CARD`; export numcards

# verify numcards/num_interface matches
if [ $num_interface -ne `expr $numcards \* $INTERFACE_PER_CARD` ]; then
  echo "  host interface list(MAXQ_SUT_IF) does not match with "
  echo "  number_of_cards * INTERFACE_PER_CARD"
  exit 1
fi

# call run_maxq ot get_TP based on MAXQ_TYPE 
if [ ${MAXQ_TYPE} = "0" ]; then
  get_TP ${numcards} ${SESSION_PER_INTERFACE} ${timeout_short}
  # run report on the test
  report_system >/tmp/sysinfo.out
  report_TP failed >>${LOGFILE}
  cat ${LOGFILE} >>/tmp/sysinfo.out
  cp /tmp/sysinfo.out ${LOGFILE}
else
  run_maxq_seq ${numcards}
  # run report on the test
  report_system >/tmp/sysinfo.out
  report_maxq failed >>${LOGFILE}
  cat ${LOGFILE} >>/tmp/sysinfo.out
  cp /tmp/sysinfo.out ${LOGFILE}

  # save test log to ${LOGDIR}
  cp /tmp/$TESTNAME/history.* ${LOGDIR}
  cp /tmp/$TESTNAME/mpstat.* ${LOGDIR}
  if [ ${sut_os} = "SunOS" ]; then
    cp /tmp/$TESTNAME/kstat.* ${LOGDIR}
  fi
fi

# mail reports
if [ ${sut_os} = "SunOS" ]; then
  mailx -s "${PRODUCT}: ${TESTNAME} results on ${HOSTNAME}" ${MAILTO} < ${LOGFILE}
elif [ ${sut_os} = "Linux" ]; then
  mail -s "${PRODUCT}: ${TESTNAME} results on ${HOSTNAME}" ${MAILTO} < ${LOGFILE}
fi

# For NSN test database only
if [ "X${TEST_MATRIX_ID}" != "X" ]
then
  if [ ${STATUS} -gt 0 ]
  then
    STATUS="F"
  else
    STATUS="P"
  fi
  RESULT_TITLE="${PRODUCT}: ${TESTNAME} results on ${HOSTNAME}"
  if [ -f /suites/utils/TestMatrix/SaveTestResults.ksh ]; then
    /suites/utils/TestMatrix/SaveTestResults.ksh -f ${LOGFILE} -t ${RESULT_TITLE} -p ${STATUS} -m ${TEST_MATRIX_ID}
  else
    echo "/suites/utils/TestMatrix/SaveTestResults.ksh does not exist"
    echo "Test results not logged in database"
  fi
fi

# save test log to ${LOGDIR}, display test log on terminal then remove it
cat ${LOGFILE}
cp ${LOGFILE} ${LOGDIR}/`basename ${LOGFILE}`
rm -f ${LOGFILE}

# cleanup if neccessary
echo "Cleanup the tests..."
cleanup

# restore original routing table if necessary...
if [ "X${MULTICAST_SUBNET}" != "X" ]; then
  # no original multicast routing entry
  echo "Restoring system routing tables if necessary..."
  if [ "X${mg_cur}" = "X" ]; then
    if [ ${sut_os} = "SunOS" ]; then
      route delete 224.0.0.0 -netmask 240.0.0.0 ${mg_new}
    elif [ ${sut_os} = "Linux" ]; then
      route del -net 224.0.0.0 netmask 240.0.0.0 ${sut_if}
    fi
  # original multicast routing entry available
  elif [ "X${mg_cur}" != "X${mg_new}" ]; then
    if [ ${sut_os} = "SunOS" ]; then
      route delete 224.0.0.0 -netmask 240.0.0.0 ${mg_new}
      route add -interface 224.0.0.0 -netmask 240.0.0.0 -gateway ${mg_cur}
    elif [ ${sut_os} = "Linux" ]; then
      route del -net 224.0.0.0 netmask 240.0.0.0 ${sut_if}
      route add -net 224.0.0.0 netmask 240.0.0.0 ${sut_if_old}
    fi
  # special case for linux that use 0.0.0.0 as gateway
  elif [ "X${mg_new}" = "X0.0.0.0" ]; then
    if [ ${sut_os} = "Linux" ]; then
      route del -net 224.0.0.0 netmask 240.0.0.0 ${sut_if}
      route add -net 224.0.0.0 netmask 240.0.0.0 ${sut_if_old}
    fi
  fi
fi

# restore tcp_time_wait_interval
echo "Restoring system tcp_time_wait_interval if necessary..."
for host in ${MAXQ_CLIENT} ${HOSTNAME}
do
  host_os=`rsh -n ${host} uname -s`
  if [ "X${host_os}" = "XSunOS" ]; then
    rsh -n ${host} "if [ -f /tmp/ndd.time_wait.sav ]; then \
                   ndd -set /dev/tcp tcp_time_wait_interval \
                   `cat /tmp/ndd.time_wait.sav`; \
                   sleep 1; \
                   rm -f /tmp/ndd.time_wait.sav; \
                   rm -f /tmp/${NET_SERVER}; \
		   rm -f /tmp/${NET_PERF}; \
                   rm -f /tmp/netserver.log; \
                 fi"
    verify_rsh $? ${host}_restore
  fi
done

if [ ${STATUS} -gt 0 ]
then
        exit 1
else
        exit 0
fi
