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

#pragma ident	"@(#)mcast_R_stress.c	1.2	08/04/22 SMI"

#include <stdio.h>
#include <signal.h>
#include <sys/wait.h>
#include <stdlib.h>
#include <errno.h>
#include <unistd.h>
#include <stropts.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>

#ifdef _LINUX_
#include <sys/ioctl.h>
#else
#include <sys/sockio.h>
#endif

#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/utsname.h>
#include <net/if.h>

#define	MAXSOCKADDR	128
#define	 MAXLINE	4096
#define	 DEFAULT_MULTICAST_ADDR "239.0.0.0"

#ifdef SOL25
typedef long int uint32_t;
typedef short uint16_t;
#endif

/*  function prototype  */
void recv_all(int,  int);
char *sock_ntop(const struct sockaddr *,  int);
int usage(char *);
int err_sys(char *);

int
main(int argc,  char **argv)
{
	int    recvfd;
	uint16_t   serv_port;
	const  int on = 1;
	struct ifreq	ifr;
	struct ip_mreq	mreq;
	struct sockaddr_in	*sa;
	struct sockaddr_in  sarecv,  tmpsa;
	uint32_t newaddr,  addr;
	int    c;
	char   *mcast,  *interface;
	int flag;

	flag = 0;	/*  INADDR_ANY  */
	interface = NULL;
	serv_port = 65000;
	mcast = DEFAULT_MULTICAST_ADDR;
	while ((c = getopt(argc,  argv,  "fhi:p:m:n:")) != -1) {
		switch (c) {
		case 'f':
			flag = 1;
			break;
		case 'p':
			serv_port = atoi(optarg);
			break;
		case 'i':
			interface = optarg;
			break;
		case 'm':
			mcast = optarg;
			break;
		case 'h':
		default:
			usage(argv[0]);
		}
	}

	if (interface == NULL) {
		fprintf(stdout,  "You must pass \
			in `-i interface` to continue\n");
		exit(1);
	}

	/*   RECEIVER CODE BELOW  */
	/*
	 *	open a UDP socket
	 */

	if ((recvfd = socket(AF_INET,  SOCK_DGRAM,  0)) < 0)
		err_sys("system call - socket()");

	/*
	 *	get interface addr
	 */

	strcpy(ifr.ifr_name,  interface);
	ioctl(recvfd,  SIOCGIFADDR,  &ifr);
	addr = ((struct sockaddr_in *)&ifr.ifr_addr)->sin_addr.s_addr;

	/*
	 *	bind socket
	 */

	sarecv.sin_family = AF_INET;
	sarecv.sin_port   = htons(serv_port);
	if (flag)
		sarecv.sin_addr.s_addr = addr;
		else
		sarecv.sin_addr.s_addr = htonl(INADDR_ANY);

	if (bind(recvfd,  (struct sockaddr *)&sarecv,  sizeof (sarecv)) < 0)
		err_sys("Can not bind socket");

	fprintf(stdout, "Receiver bound to %s on interface %s.\n",
	    inet_ntoa(sarecv.sin_addr),  interface);

	newaddr = inet_addr(mcast);
	tmpsa.sin_addr.s_addr = newaddr;
	fprintf(stdout, "Joined multicast group %s - ",
	    inet_ntoa(tmpsa.sin_addr));
	mreq.imr_multiaddr.s_addr = newaddr;
	sa = (struct sockaddr_in *)&ifr.ifr_addr;
	mreq.imr_interface.s_addr = sa->sin_addr.s_addr;

	if (setsockopt(recvfd,  IPPROTO_IP,  IP_MULTICAST_IF,
	    (char *)&addr,  sizeof (addr)) < 0)
		err_sys("Can not set multicast bit on interface");
	if (setsockopt(recvfd,  IPPROTO_IP,  IP_ADD_MEMBERSHIP,
	    (char *)&mreq,  sizeof (mreq)) < 0)
		err_sys("Can not join multicast multicast group");

	fprintf(stdout, "%s on %s.\n",  inet_ntoa(tmpsa.sin_addr),  interface);
	fflush(stdout);

	recv_all(recvfd,  sizeof (sarecv));
	return (0);
}

void
recv_all(int recvfd,  int salen)
{
	int	n;
	char	line[MAXLINE+1];
	int	len;
	struct sockaddr *safrom;
	char    *finish = "ENDOFTEST";
	int  pcnt = 0;

	safrom = (struct sockaddr *)malloc(salen);

	for (;;) {
		len = salen;
		n = recvfrom(recvfd,  line,  MAXLINE,  0,  safrom,  &len);
		if (n < 0)
			err_sys("system call recvfrom()");
		else {
			line[n] = 0;	/*  null terminate  */
			pcnt++;
			if (pcnt%1000000 == 0) {
				fprintf(stdout, " .");
				fflush(stdout);
			}

			if (memcmp(line,  finish,  strlen(finish)) == 0) {
				fprintf(stdout, "\n finished \n");
				exit(0);
			}
		}
	}
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
	fprintf(stdout,  "Usage: %s -f -h -i interface -p \
		port -m MIP \n",  prog);
	fprintf(stdout,  "\t-h :help info\n");
	fprintf(stdout,  "\t-f :use specific interface(-f), \
		otherwise INADDR_ANY\n");
	fprintf(stdout,  "\t-m :multicast address\n");
	fprintf(stdout,  "\t-p :port number,  default=65000\n");
	fprintf(stdout,  "\t-i :interface name such as hme0,  ce0 etc.\n");
	exit(1);
	return (0);
}

char *
sock_ntop(const struct sockaddr *sa,  int salen)
{
	char    portstr[7];
	static  char str[128];

	switch (sa->sa_family) {
	case AF_INET:
		{
			struct sockaddr_in *sin = (struct sockaddr_in *)sa;
#ifdef  IPV6
			if (inet_ntop(AF_INET,  &sin->sin_addr,  str,
			    sizeof (str)) == NULL)
				return (NULL);
#else
			strcpy(str,  (const char *)inet_ntoa(sin->sin_addr));
#endif
			if (ntohs(sin->sin_port) != 0) {
#ifdef SOL25
				sprintf(portstr,  ".%d",  ntohs(sin->sin_port));
#else
				snprintf(portstr,  sizeof (portstr),  ".%d",
				    ntohs(sin->sin_port));
#endif
				strcat(str,  portstr);
			}
			return (str);
		}
	}
}
