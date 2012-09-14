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
# ident	"@(#)nic_ftp.rc.ksh	1.2	08/04/22 SMI"
#

# Remote interface name/address to run ftp test with
# Any number of interfaces can be specified seperated by ,
# Eg. "test-qfe0,test-ge1,test-ce0"
# This is a required field
REMOTE_INT=""

# Size of file to be used for ftp test with a m|k|b
# Eg. 100m or 2g
# This is not a required field. Default is 10m
FTP_SIZE="100m"

# Time for which ftp test should be run (in seconds)
# This is not a required field. Default is 3600 seconds
FTP_TIME="120"

# Root password for the test machine to run ftp tests
# This is a required field. 
FTP_PASSWD="mypassword"

# Email address where log files need to be mailed to
# Not a required field. Default is "root" 
MAILTO="root@localhost"

# Product name being tested
# This is a required field, since no default value can be assumed
PRODUCT="nic"

# Variable to set user preference for whether tests
# should be stopped on encountering first error or
# tests should be continued even if error occurs
# 1 - Stop on first error
# 0 - Continue inspite of error
# This is not a required field. Default is continue inspite of error
STOP_ON_ERR=0

# For NSN auto report only.
# This should set to your Hostnames and TestMatrixIds of the systems
# you want to collect data on. Usually this is just the SUT but you
# can also list clients to gather data on with its respective TestMatrixId.
# Each client only needs listed once. The hostname must be accessible from
# the SUT.  The format is <host1:TestmatrixId1>,<host2:TestmatrixId2>.
# For Example:
#     TEST_MATRIX_ID=nspgqa145c:205,nspgqa23b:534
# You should have /suites/utils/TestMatrix/* test utility on SUT
# Comment it out if you do not want to insert test log into database
#TEST_MATRIX_ID=""
