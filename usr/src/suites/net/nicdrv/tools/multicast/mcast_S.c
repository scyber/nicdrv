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

#pragma ident	"@(#)mcast_S.c	1.2	08/04/22 SMI"

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

#define	SENDRATE	5    /*  send datagram every 5 seconds  */
#define	MAXSOCKADDR	128
#define	MAXLINE	4096
#define	 DEFAULT_MULTICAST_ADDR "239.0.0.0"

#ifdef SOL25
typedef long int uint32_t;
typedef short uint16_t;
#endif

/*  function prototype  */
void send_all(int, struct sockaddr_in, int, char *);
int mcast_set_loop(int, int);
int Socket(int, int, int);
int sockfd_to_family(int);
char *sock_ntop(const struct sockaddr *, int);
static void sigalarm(int);
int usage(char *);
int err_sys(char *);

int count, second, run, timeout;

int
main(int argc, char **argv)
{
	int    sendfd;
	char   ttl = 4;
	uint16_t   serv_port;
	const	int on = 1;
	struct ifreq	ifr;
	struct ip_mreq	mreq;
	struct sockaddr_in  *sa;
	struct sockaddr_in  sasend, remote;
	int    remotelen;
	uint32_t newaddr, addr;
	int    c;
	char   *mcast, *interface;
	int    i;

	count = 1;
	interface = NULL;
	serv_port = 5500;
	mcast = DEFAULT_MULTICAST_ADDR;
	second = SENDRATE;
	run = 1;
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
		case 'n':
			count = atoi(optarg);
			break;
		case 's':
			second = atoi(optarg);
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
		fprintf(stdout, "You must pass \
			in `-i interface` to continue\n");
		exit(1);
	}
	fprintf(stdout, "Estimated test run: %d minutes\n", timeout);

	/*
	 *	open a UDP socket
	 */

	sendfd = Socket(AF_INET, SOCK_DGRAM, 0);

	/*
	 *	get interface addr
	 */

	strcpy(ifr.ifr_name, interface);
	ioctl(sendfd, SIOCGIFADDR, &ifr);
	addr = ((struct sockaddr_in *)&ifr.ifr_addr)->sin_addr.s_addr;

	/*
	 *	bind socket
	 */

	sasend.sin_family = AF_INET;
	sasend.sin_port   = htons(0);
	sasend.sin_addr.s_addr = addr;

	if (bind(sendfd, (struct sockaddr *)&sasend, sizeof (sasend)) < 0)
		err_sys("Can not bind socket");
	fprintf(stdout, "Sender bound to %s on interface %s.\n",
	    inet_ntoa(sasend.sin_addr), interface);

	/*
	 *	set ttl
	 */

	if (setsockopt(sendfd, IPPROTO_IP, IP_MULTICAST_TTL,
	    &ttl, sizeof (ttl)) == -1)
		err_sys("Cannot set ttl");

	/*
	 *	start sender(parent)
	 */
	remote.sin_family = AF_INET;
	remote.sin_port = htons(serv_port);
	remote.sin_addr.s_addr = inet_addr(mcast);
	remotelen = sizeof (struct sockaddr_in);

	send_all(sendfd, remote, remotelen, mcast);  /*  parent  */
	return (0);
}

void
send_all(int sendfd, struct sockaddr_in sadest, int salen, char *mcast)
{
	static char line[MAXLINE];
	struct utsname myname;
	uint32_t newaddr;
	uint32_t tmpaddr;
	int    i, n;
	uint32_t	send_pkt = 0, send_byte = 0;

	if (uname(&myname) < 0)
		err_sys("uname error");


	/*  list_modules(sendfd);  */
	(void) signal(SIGALRM, sigalarm);
	if (alarm(timeout*60) < 0)
		err_sys("system call - alarm()");

	while (run) {
		newaddr = inet_addr(mcast);
		for (i = 0; i < count; i++)  {
			sadest.sin_addr.s_addr = newaddr;
#ifdef SOL25
			sprintf(line, "hostname:%s to %s\n", myname.nodename,
			    inet_ntoa(sadest.sin_addr));
#else
			snprintf(line, sizeof (line), "hostname:%s to %s\n",
			    myname.nodename, inet_ntoa(sadest.sin_addr));
#endif
			n = sendto(sendfd, line, strlen(line), 0,
			    (struct sockaddr *)&sadest, salen);
			if (n < 0)
				err_sys("system call sendto()");
			else {
				fprintf(stdout, "Send to: IP %s \n",
				    inet_ntoa(sadest.sin_addr));
				fflush(stdout);
				send_pkt++;
				send_byte += n;
				sleep(second);
				/* next address, lt */
				tmpaddr = ntohl(newaddr);
				tmpaddr++;
				newaddr = htonl(tmpaddr);

				/*  newaddr++; old code */
			}
		}
	}
	fprintf(stdout, "Send multicast packet:%u byte:%u\n",
	    send_pkt, send_byte);
	fflush(stdout);

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

static void sigalarm(int val)    /* make it compatible with signal.h. lt */
{
	run = 0;	/*  set run flag =0(stop running)  */
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
	fprintf(stdout, "Usage: %s -h -i interface -p port -m MIP \
			-n count -s second -t timeout\n", prog);
	fprintf(stdout, "\t-h :help info\n");
	fprintf(stdout, "\t-i :interface name such as hme0, ce0 etc.\n");
	fprintf(stdout, "\t-m :multicast address base, default=239.0.0.0\n");
	fprintf(stdout, "\t-p :port number, default=5500\n");
	fprintf(stdout, "\t-n :number of multicast addresses, default=1\n");
	fprintf(stdout, "\t-s :send rate in seconds, default=5\n");
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

int
sockfd_to_family(int sockfd)
{
	union {
		struct sockaddr sa;
		char   data[MAXSOCKADDR];
	} un;
	int   len;

	len = MAXSOCKADDR;
	if (getsockname(sockfd, (struct sockaddr *)un.data, &len) < 0)
		return (-1);
	return (un.sa.sa_family);
}

char *
sock_ntop(const struct sockaddr *sa, int salen)
{
	char    portstr[7];
	static  char str[128];

	switch (sa->sa_family) {
	case AF_INET:
		{
			struct sockaddr_in *sin = (struct sockaddr_in *)sa;
#ifdef  IPV6
			if (inet_ntop(AF_INET, &sin->sin_addr, str,
			    sizeof (str)) == NULL)
				return (NULL);
#else
			strcpy(str, (const char *)inet_ntoa(sin->sin_addr));
#endif
			if (ntohs(sin->sin_port) != 0) {
#ifdef SOL25
				sprintf(portstr, ".%d", ntohs(sin->sin_port));
#else
				snprintf(portstr, sizeof (portstr), ".%d",
				    ntohs(sin->sin_port));
#endif
				strcat(str, portstr);
			}
			return (str);
		}
	}
}

#if 0  /* not used */
list_modules(int fd)
{
	int    nmod, i;
	struct strioctl str;
	struct str_list list;

	/*  List stream modules  */
	nmod = ioctl(fd, I_LIST, (caddr_t)NULL);
	if (nmod < 0) {
		perror("I_LIST");
		exit(1);
	}
	list.sl_nmods = nmod;
	list.sl_modlist = (struct str_mlist *)malloc(nmod * \
	    sizeof (struct str_mlist));
	if (ioctl(fd, I_LIST, &list) < 0) {
		perror("I_LIST");
		exit(1);
	}
	fprintf(stdout, "Stream modules: ");
	for (i = 0; i < nmod; i++)
		printf("%s ", list.sl_modlist[i].l_name);
	printf("\n");
}
#endif
