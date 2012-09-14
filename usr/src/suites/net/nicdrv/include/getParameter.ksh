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
# ident	"@(#)getParameter.ksh	1.2	08/04/25 SMI"
#
#
#
# Function name get_parameter
#
# Purpose:
# 	dynamically get_parameter by parameter environment setting
#
# Arguments:
#
# $1 the parameter's baseName
# $2 ... $n optional suffix for the parameter, if there is no one specified, will call get_default_parameter
#
# This function will check the following parameterName combination and return  the first not-null parameter value
# $1_$2_$3....$n
# $1_$2_$3...$n-1
# $1_$2
# $1
# Return 1 if the the parameter is not set or set to null
#
get_parameter() {

	if [ $# -eq 1 ]; then
		get_default_parameter $1
		return 
	fi
        typeset parameterName=""
	typeset result=""

        for i in $*; do
                if [ -z "${parameterName}" ]; then
                        parameterName=$i       
                else
                        parameterName=${parameterName}_$i
                fi
		typeset tmp=`get_simple_parameterValue $parameterName`
		if [ -n "$tmp" ]; then
			result=$tmp
		fi
        done
	echo $result
	if [ -z "$result" ]; then
		return 1
	fi
			
}

#
# get_parameter by appending RUN_MODE DRIVER_NAME and DRIVER_SPEED 
# $1 the parameter baseName
# the function will compose the following parameter name and return the first not-null value
# $1_${RUN_MODE}_${DRIVER_NAME} 
# $1_${RUN_MODE}_${DRIVER_SPEED} 
# $1_${RUN_MODE}
# $1
#
get_default_parameter() {

	typeset result=""

	if [ -n "$DRIVER_NAME" ]; then
		result=`get_composite_parameterValue $1 $RUN_MODE $DRIVER_NAME` 
	fi


	if [ -z "${result}" ] && [ -n "$DRIVER_SPEED" ]; then
		result=`get_composite_parameterValue $1 $RUN_MODE $DRIVER_SPEED`
	fi

	if [ -z "${result}" ] && [ -n "$RUN_MODE" ] ; then
		result=`get_composite_parameterValue $1 $RUN_MODE`
	fi
	
	if [ -z "${result}" ]; then
		result=`get_simple_parameterValue $1`
	fi

 	echo $result	

	if [ -z "$result" ]; then
		return 1
	fi
}

#
# compose one parameter name and return the value for it
# $1, $2, $3... parameter baseName and suffix
#
#
get_composite_parameterValue() {
	if [ $# -eq 0 ]; then
		echo "Error calling get_composite_parameterValue" 1>&2
		return 1
	fi	
	typeset parameterName=""
	for i in $*; do
		if [ -z "${parameterName}" ]; then
			parameterName=$i	
		else
			parameterName=${parameterName}_$i
		fi	
	done
	get_simple_parameterValue $parameterName
}

#
# get the parameter value for a parameterName
# $1 is the parameterName
#
get_simple_parameterValue() {
	eval echo \$$1
}




