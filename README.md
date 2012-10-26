NIC-Driver-Test-Suite install Guide
==================================
1. Install zfstest https://github.com/delphix/zfstest
2. Prepare two servers Client and Server with two network interfaces.
3. Build 
* Add C compiler and STF path to environment.

# PATH=/opt/SUNWspro/bin:/opt/SUNWstc-stf/bin/`isainfo -n`:$PATH;
# export PATH

* Define the environment variable CODEMGR_WS.

# CODEMGR_WS=<local_ws>
# export CODEMGR_WS

* Change to nicdrv source directory.

# cd ${CODEMGR_WS}/src/suites/net/nicdrv

* Build the nicdrv test suite.

# stf_build

* Change to <SUITE_ROOT> directory.

# cd <local_ws>/proto/suites/net/nicdrv 

4. Add PATH to run tests

PATH=/opt/SUNWspro/bin:/opt/SUNWstc-stf/bin/`isainfo -n`:$PATH;
export PATH

5. Following files should be changed.

Please set the appropriate values for the mandatory variables
specified in <SUITE_ROOT>/config.vars using 'stf_configure -c'
or 'stf_configure -f'

The following options need to be changed:

TST_INT=
TST_NUM=
RMT_INT=
RMT_NUM=
LOCAL_HST=
RMT_HST=
TST_PASS=
NETPERF_HOME=
RUN_MODE=

For details on the options listed above, please refer to comments of
the config.vars file. Note TST_INT should be network card of LOCAL_HST IP or hostname
 

In the <SUITE_ROOT> directory, run: 
# stf_configure

6. Run stf tests.

Execute the test suites still in the <SUITE_ROOT> directory

# stf_execute -m `isainfo -n`

7. Examples and results

While the test is being executed, you can view the journal file at:
/var/tmp/SUNstc-nicdrv/results, for example 
"tail -f /var/tmp/nicdrv/results/journal.hostname1.20070821185114.execute.i386"


