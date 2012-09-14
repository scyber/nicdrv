/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
 * or http://www.opensolaris.org/os/licensing.
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at usr/src/OPENSOLARIS.LICENSE.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */

/*
 * Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#pragma ident	"@(#)mcast_S_stress.c	1.2	08/04/22 SMI"

#include <stdio.h>
#include <stdlib.h>
#include <sys/signal.h>
#include <errno.h>
#include <unistd.h>
#include <stropts.h>
#include <sys/ioctl.h>
#include <sys/fcntl.h>
#include <string.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <signal.h>

#ifdef _LINUX_
#include <sys/ioctl.h>
#else
#include <sys/stream.h>
#include <sys/sockio.h>
#endif

#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/utsname.h>
#include <net/if.h>
#include <netdb.h>

#define	 MAXSOCKADDR 128
#define	 MAXLINE 4096
#define	 DEFAULT_MULTICAST_ADDR "239.0.0.0"

#ifdef SOL25
typedef long int uint32_t;
typedef short uint16_t;
#endif

/*  function prototype  */
void send_all(int, struct sockaddr_in, int, char *);
int Socket(int, int, int);
static void sigalarm(int);
int usage(char *);
int err_sys(char *);

int nanosecond, run, timeout;
static struct timespec ts;

int
main(int argc, char **argv)
{
	int    sendfd;
	char   ttl = 4;
	uint16_t   serv_port;
	/* char	 on = 1; */
	int on = 1; /*  need 4 bytes */
	struct ifreq ifr;
	struct ip_mreq	mreq;
	struct sockaddr_in  *sa;
	struct sockaddr_in  sasend, remote;
	int    remotelen;
	uint32_t newaddr, addr;
	int    c;
	char   *mcast, *interface;

	interface = NULL;
	serv_port = 65000;
	mcast = DEFAULT_MULTICAST_ADDR;
	run = 1;
	nanosecond = 0;
	timeout = 60;
	while ((c = getopt(argc, argv, "hi:p:m:n:s:t:")) != -1) {
		switch (c) {
		case 'p':
			serv_port = atoi(optarg);
			break;
		case 'i':
			interface = optarg;
			break;
		case 'm':
			mcast = optarg;
			break;
		case 's':
			nanosecond = atoi(optarg);
			break;
		case 't':
			timeout = atoi(optarg);
			break;
		case 'h':
		default:
			usage(argv[0]);
		}
	}

	if (interface == NULL) {
		fprintf(stdout, "You must pass in `-i interface` to \
			continue\n");
		exit(1);
	}
	fprintf(stdout, "Estimated test run: %d minutes\n", timeout);

	/*  setup ts structure  */
	ts.tv_sec = 0;
	ts.tv_nsec = nanosecond;

	/*
	 *	open a UDP socket
	 */

	sendfd = Socket(AF_INET, SOCK_DGRAM, 0);

	/*
	 * get interface addr
	 */

	strcpy(ifr.ifr_name, interface);
	ioctl(sendfd, SIOCGIFADDR, &ifr);
	addr = ((struct sockaddr_in *)&ifr.ifr_addr)->sin_addr.s_addr;

	/*
	 * bind socket
	 */

	sasend.sin_family = AF_INET;
	sasend.sin_port   = htons(0);
	sasend.sin_addr.s_addr = addr;

	if (bind(sendfd, (struct sockaddr *)&sasend, sizeof (sasend)) < 0)
		err_sys("Can not bind socket");
	fprintf(stdout, "Sender bound to %s on interface %s.\n",
	    inet_ntoa(sasend.sin_addr), interface);

	/*
	 * set ttl
	 */

	if (setsockopt(sendfd, IPPROTO_IP, IP_MULTICAST_TTL,
	    &ttl, sizeof (ttl)) == -1)
		err_sys("Cannot set ttl");

	if (setsockopt(sendfd, SOL_SOCKET, SO_BROADCAST,
	    &on, sizeof (on)) == -1)
		err_sys("Cannot set SO_BROADCAST");

	/*
	 * start sender
	 */
	remote.sin_family = AF_INET;
	remote.sin_port = htons(serv_port);
	remote.sin_addr.s_addr = inet_addr(mcast);
	remotelen = sizeof (struct sockaddr_in);

	send_all(sendfd, remote, remotelen, mcast);
	return (0);
}

void
send_all(int sendfd, struct sockaddr_in sadest, int salen, char *mcast)
{
	static char line[MAXLINE];
	struct utsname myname;
	uint32_t newaddr;
	int    i, n;

	if (uname(&myname) < 0)
		err_sys("uname error");


	(void) signal(SIGALRM, sigalarm);
	if (alarm(timeout*60) < 0)
		err_sys("system call - alarm()");

	newaddr = inet_addr(mcast);
	sadest.sin_addr.s_addr = newaddr;
#ifdef SOL25
	sprintf(line, "%s to %s\n", myname.nodename,
	    inet_ntoa(sadest.sin_addr));
#else
	snprintf(line, sizeof (line), "%s to %s\n", myname.nodename,
	    inet_ntoa(sadest.sin_addr));
#endif
	while (run) {
		n = sendto(sendfd, line, strlen(line), 0,
		    (struct sockaddr *)&sadest, salen);
		if (n < 0)
			/* for stress test, don't exit, just go on. lt */
			perror("system call sendto()");
		if (nanosecond > 0)
			nanosleep(&ts, (struct  timespec *)NULL);
	}

	/*  send ENDOFTEST message to stop test  */
#ifdef SOL25
	sprintf(line, "%s\n", "ENDOFTEST");
#else
	snprintf(line, sizeof (line), "%s\n", "ENDOFTEST");
#endif
	for (i = 0; i < 2; i++) {
		n = sendto(sendfd, line, strlen(line), 0,
		    (struct sockaddr *)&sadest, salen);
		sleep(25);
	}
}

static void
sigalarm(int val)
{
	run = 0; /*  set run flag =0(stop running)  */
}

/*  Fatal error related to a system call print a message and terminate  */
int
err_sys(char *s)
{
	(void) perror(s);
	exit(1);
	return (0);
}

int
usage(char *prog)
{
	fprintf(stdout, "Usage: %s -h -i interface -p port -m MIP -s \
		nanosecond -t timeout\n", prog);
	fprintf(stdout, "\t-h :help info\n");
	fprintf(stdout, "\t-i :interface name such as hme0, ce0 etc.\n");
	fprintf(stdout, "\t-m :multicast address base, default=239.0.0.0\n");
	fprintf(stdout, "\t-p :port number, default=65000\n");
	fprintf(stdout, "\t-s :send delay in nanosecond, default=0\n");
	fprintf(stdout, "\t-t :sender timeout in minutes, default=60\n");
	exit(1);
	return (0);
}

int
Socket(int family, int type, int protocol)
{
	int	n;

	if ((n = socket(family, type, protocol)) < 0)
		err_sys("socket error");

	return (n);
}
