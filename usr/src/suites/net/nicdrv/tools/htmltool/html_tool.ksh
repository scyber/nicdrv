#!/usr/bin/ksh93
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
# ident	"@(#)html_tool.ksh	1.1	09/06/24 SMI"
#

#
# Function gen_html_frame
# Generate html page framework
# Argument
# $1 - display test type(function,stress,performance)
# Useage
# gen_html_frame function
#
gen_html_frame() {
	typeset count=0
	typeset function=$1
	print "<html>
	<style TYPE=\"text/css\">
	.testdetail {display:none}
	</style>
	<script>
	function showTest(testcase)
	{
		document.all(\"result\").innerHTML=document.all(testcase).innerHTML;
	}
	</script>
	<body>
	<h2>$function Test Report</h2>
	<table CELLSPACING=10>
	<tr VALIGN=top>
	<td NOWRAP> 
	Start time ${timelist[0]} <br>
	End time ${end_time} <br>
	${envlist[1]}<br>
	${envlist[2]}<br> 
	${envlist[3]}<br>" >>$output
	while (( $count < $testcount && $count < $flagcount )); do
		print "<a href=# onclick=\"showTest('${testlist[$count]}')\">
		    ${testlist[$count]}
		    <span class=\"${flaglist[$count]}\">
		    ${flaglist[$count]}</span></a><br>" >> $output
		count=$((count=count+1))
	done

	print "</td>
	<td><div id=\"result\"></div></td>
	</tr>
	</table>" >>$output
	print "<style type=\"text/css\">\
		span.pass {
			color:green;
		}
		span.fail {
			color:red;
		}
		span.UNSUPPORTED {
			color:orange;
		}
		</style>" >> $output
}

#
# Function paser_log_file
# Argument:
# $1 - log file name
#
paser_log_file()
{
	typeset testcount=0
	typeset flagcount=0
	typeset timecount=0
	typeset envcount=0
	cat $1 | while read LINE; do
		field=$(echo $LINE | gawk -F "[|]" '{print $1}')
		case $field in
			Test_Case_Start)
				name=$(echo $LINE | gawk -F "[ |]" '{print $4}')
				testlist[$testcount]=$name
				print "<div id=\"$name\" CLASS=\"testdetail\">\n
				    <pre>\n $LINE" >> $output
				(( testcount = testcount + 1 ))
				;;

			Test_Case_End)
				flag=$(echo $LINE | gawk -F "[ |]" '{print $7}')
				flaglist[$flagcount]=$flag
				(( flagcount = flagcount + 1 ))
				print "$LINE \n</pre>\n
				    </div>\n" >> $output
				;;
			Start)
				start_time=$(echo $LINE | gawk -F "[| ]" '{print $12}' | head -n 1)
				timelist[$timecount]=$start_time
				(( timecount = timecount + 1 ))
				;;
			End)
				end_time=$(echo $LINE | gawk -F "[| ]" '{print $4}')
				;;
			STF_ENV)
				env_setting=$(echo $LINE | gawk -F "[|]" '{print $2}')
				envlist[$envcount]=$env_setting
				(( envcount = envcount + 1 ))
				;;
			*)
				echo $LINE >> $output
				;;
		esac	
	done
}

usage()
{
	echo "\nUsage: `basename $0` --help | \
		-f journal name -o output dir \
		-n test name"
	echo "  Options:"
	echo "		--help:	Help information"
	echo "		-f:	journal name"
	echo "		-o:	html output dir"
	echo "		-n:	test suite name"
	echo "  Example:"
	echo "		./html_tool.auto --help"
	echo "		./html_tool.auto -f file.execute.amd64 -o /tmp -n NICDRV"
}

if [ $# -eq 0 ]; then
	usage
	exit 0
fi

for i in $*; do
    case $1 in
       -f) FILE=$2
           export FILE
           shift 2
           ;;
       -o) OUT_DIR=$2
           export OUT_DIR
           shift 2
           ;;
       -n) TEST_SUITE=$2
           export TEST_SUITE 
           shift 2
           ;;
	--help) usage
		exit 0
		;;
   esac
done

if [ -z "$FILE" ] ; then
	echo "Please input a journal file name!"
	usage
	exit 0
fi
output_path=$OUT_DIR
if [ -z "$output_path" ]; then
	output_path=$(pwd)
fi


if [ ! -d "$output_path" ]; then
	echo "output dir not exist"
	exit 1
fi

index=$(basename $FILE).html
output=$output_path/$index
paser_log_file $FILE
gen_html_frame $TEST_SUITE
