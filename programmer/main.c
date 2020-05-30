/*
 *
 * Odyssey 2 bootloader programmer
 *
 * Copyright (C) 2020 Davide Gerhard IV3CVE
 *
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 */

/*
 * TODO:
 *  - move to DHCP and discovery
 *  - INET with subnet
 *  - INET6
 *  - version autodiscovery
 *
 * REQUIREMENTS:
 *  - mingw to build for windows
 */

#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>
/* require mingw in windows */
#include <getopt.h>
#include <sys/stat.h>
#if defined(WIN32) || defined(__WIN32__)
#include <winsock2.h>
#else
#include <arpa/inet.h>
#include <sys/socket.h>
#endif

#define MAJOR_VERSION "0"
#define MINOR_VERSION "1"
#define PATCH_LEVEL   "0"
#define SOFTWARE_VERSION MAJOR_VERSION "." MINOR_VERSION "." PATCH_LEVEL
#define SOFTWARE_NAME "Odyssey 2 Bootloader Programmer"
#define SOFTWARE_CONTACT "IV3CVE"

/* avoid C99 as requirement */
typedef enum { false, true } bool;

/* bootloader slots are from 0 to 3 */
#define SLOT_NUMS 3
#define FIRMWARE_EXTENSION ".rbf"
#define FIRMWARE_MAX_SIZE 32*256*1024
#define FIRMWARE_CHUNK 256
/* generic buffer dimension */
#define BUF_LEN 64
char firmware_file[PATH_MAX+1];

/* programmer binary name */
char *bin_name;

/* used to add a delay between the reset and the next command
   permit command concatenation in seconds */
#define WAIT_AFTER_RESET 3

/* Bootloader */
#define BOOTLOADER_PORT 50000
#define UDP_CMD_LEN 32
#define UDP_MSG_LEN UDP_CMD_LEN + FIRMWARE_CHUNK
#define RETRY_STOP_BOOT 1000
char msg[UDP_MSG_LEN];
unsigned long msg_size = UDP_CMD_LEN;
char bootloader_cmds[][3] = {
  "RES", /* 0  = reset the device */
  "MAC", /* 1  = request mac address */
  "WIP", /* 2  = change the IP address */
  "ERS", /* 3  = erase slot */
  "WPD", /* 4  = write the new firmware */
  "STS", /* 5  = request the status (amplifiers, slot, version, ..) */
  "EAA", /* 6  = enable/disable the audio amplifier */
  "EPA", /* 7  = enable/disable the power amplifier (1W) */
  "STP", /* 8  = stop the loading at the bootloader */
  "SLC", /* 9  = set the slot to boot */
  "PWN", /* 10 = set the auto power on functionality */
  "BOT"  /* 11 = boot the radio firmware */
};

/* Socket */
#define UDP_BUF_LEN 1024
/* socket timeout in secconds */
#define UDP_TIMEOUT_SEC 1
#define UDP_TIMEOUT_USEC 0
#if defined(WIN32) || defined(__WIN32__)
SOCKET udp_sockfd;
#else
int udp_sockfd;
#endif
char udp_buffer[UDP_BUF_LEN];
char msg_back[UDP_BUF_LEN];
struct sockaddr_in udp_servaddr;

/* struct that describe the device in use */
struct odyssey2_t {
  char bootloader_version[BUF_LEN+1];
  unsigned short firmware_slot;
  bool power_amplifier;
  bool audio_amplifier;
  bool auto_poweron;
  char current_ip[BUF_LEN+1];
  char mac_address[BUF_LEN+1];
  char new_ip[BUF_LEN+1];
};
struct odyssey2_t odyssey2 = { "", 1, false, false, false, "", "", ""};

/* input parameters */
struct argparser_t {
  bool test;
  bool set;
  bool program;
  bool stop;
  bool reset;
  bool boot_slot;
  bool status;
  bool pa;
  bool aa;
  bool erase;
  bool poweron;
  bool start_radio;
};
struct argparser_t argp = { false, false, false, false, false,
  false, false, false, false, false, false, false };

/**
 * @brief print the help
 *
 */
static void
usage()
{
  printf("%s - Version: %s\n", SOFTWARE_NAME, SOFTWARE_VERSION);
  printf("\n");
  printf("Usage:\n");
  printf("%s ACTIONS [OPTIONS]\n", bin_name);
  printf("\n");
  printf("Actions: all require -d\n");
  printf("\t-t\t\t\ttest if the IP address is alive\n");
  printf("\t-a\t\t\tget the bootloader status\n");
  printf("\t-n\t\t\tset the new IP address; require -e\n");
  printf("\t-p\t\t\tprogram a new firmware\n");
  printf("\t\t\t\trequire -f and -o optionally; use slot 1 as default\n");
  printf("\t-x\t\t\terase the slot without programming (require -o)\n");
  printf("\t-b\t\t\tstop the radio at the bootloader\n");
  printf("\t-r\t\t\treset the device\n");
  printf("\t-z\t\t\tboot the radio firmware\n");
  printf("\t-s\t\t\tset which slot to boot (require -o)\n");
  printf("\t-y [0/1]\t\tdisable or enable the auto power-on functionality\n");
  printf("\t-g [0/1]\t\tdisable or enable the 1W power amplifier\n");
  printf("\t-c [0/1]\t\tdisable or enable the audio amplifier\n");
  printf("\n");
  printf("Options:\n");
  printf("\t-d [IP]\t\t\tset the device IP\n");
  printf("\t-e [NEW IP]\t\tset the new IP for the device\n");
  printf("\t-f [RBF]\t\tfirmware file with extension .rbf\n");
  printf("\t-o [SLOT]\t\twhich slot to use; from 0 to %d\n", SLOT_NUMS);
  printf("\n");
  printf("Notes:\n");
  printf("  [IP] must be in form 192.168.1.100 without subnet or CIDR\n");
  printf("  [SLOT] is a number from 0 to 3. 0 is the bootloader, so pay attention ;-)\n");
  exit(0);
}


/**
 * @brief custom strsep() for using also on windows
 *
 * @param stringp string to analyze
 * @param delim delimiter to find
 */
static char*
custom_strsep(char** stringp, const char* delim)
{
  char* start = *stringp;
  char* p;

  p = (start != NULL) ? strpbrk(start, delim) : NULL;

  if (p == NULL)
    {
      *stringp = NULL;
    }
  else
    {
      *p = '\0';
      *stringp = p + 1;
    }

  return start;
}

/**
 * @brief check if ip is valid or not
 *
 * @param ip the IP to validate
 *
 * @return true if it is a valid IPv4/IPv6 address otherwise false
 */
bool
validate_ip(char *ip)
{
#if defined(WIN32) || defined(__WIN32__)
  if (inet_addr(ip) == INADDR_NONE)
#else
    if (inet_aton(ip, &udp_servaddr.sin_addr) == 0)
#endif
      return false;
    else
      return true;
}

#if defined(WIN32) || defined(__WIN32__)
char errmsg[256];

/**
 * @brief print error code on windows
 *
 * @param errcode the error code to print
 */
char* sockerr(int errcode)
{
  DWORD len = FormatMessageA(FORMAT_MESSAGE_ARGUMENT_ARRAY | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, NULL, errcode, 0, errmsg, 255, NULL);
  if (len != 0)
    errmsg[len] = 0;
  else
    sprintf(errmsg, "error %d", errcode);
  return errmsg;
}

/**
 * @brief initialize the socket (only windows)
 */
void
init_socket()
{
  WSADATA wsadata;
  int err;

  err = WSAStartup (MAKEWORD(2,2), &wsadata);
  if (err != 0) {
    fprintf(stderr, "WSAStartup: %s\n", sockerr(err));
    exit(EXIT_FAILURE);
  }

  if (LOBYTE(wsadata.wVersion) != 2 || HIBYTE(wsadata.wVersion) != 2) {
    WSACleanup();
    fprintf(stderr, "WSAStartup: %s\n", sockerr(WSAGetLastError()));
    exit(EXIT_FAILURE);
  }
}
#endif

/**
 * @brief set the UDP session timeout
 *
 * @param timeout_sec timeout in secconds
 * @param timeout_usec timeout in micro seconds
 */
void
set_timeout(unsigned int timeout_sec, unsigned int timeout_usec)
{
#if defined(WIN32) || defined(__WIN32__)
  /* in windows the value is in milliseconds */
  int timeout = timeout_sec*1000 + timeout_usec;
#else
  struct timeval timeout;
  /* declare timeout value for the socket */
  timeout.tv_sec = timeout_sec;
  timeout.tv_usec = timeout_usec;
#endif
  if (setsockopt (udp_sockfd, SOL_SOCKET, SO_SNDTIMEO,
                  (char *)&timeout, sizeof(timeout)) < 0)
    {
#if defined(WIN32) || defined(__WIN32__)
      fprintf(stderr, "setsockopt failed: %s\n", sockerr(WSAGetLastError()));
#else
      perror("setsockopt failed");
#endif
      exit(EXIT_FAILURE);
    }
  if (setsockopt (udp_sockfd, SOL_SOCKET, SO_RCVTIMEO,
                  (char *)&timeout, sizeof(timeout)) < 0)
    {
#if defined(WIN32) || defined(__WIN32__)
      fprintf(stderr, "setsockopt failed: %s\n", sockerr(WSAGetLastError()));
#else
      perror("setsockopt failed");
#endif
      exit(EXIT_FAILURE);
    }
}

/**
 * @brief close the socket
 */
void
close_socket()
{
#if defined(WIN32) || defined(__WIN32__)
  closesocket(udp_sockfd);
  WSACleanup();
#else
  close(udp_sockfd);
#endif
}

/**
 * @brief create a socket
 *
 * @param dest_ip destination IP of the socket
 */
void
create_socket(char *dest_ip)
{
  int r;

  memset(&udp_servaddr, 0, sizeof(struct sockaddr_in));

  /* Creating socket file descriptor */
  if ((udp_sockfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0)
    {
#if defined(WIN32) || defined(__WIN32__)
      fprintf(stderr, "socket failed: %s\n", sockerr(WSAGetLastError()));
#else
      perror("socket creation failed");
#endif
      exit(EXIT_FAILURE);
    }

#if defined(WIN32) || defined(__WIN32__)
  if((udp_servaddr.sin_addr.s_addr = inet_addr(dest_ip)) == INADDR_NONE)
    {
      fprintf(stderr, "socket failed: %s\n", sockerr(WSAGetLastError()));
      exit(EXIT_FAILURE);
    }
#else
  if (inet_aton(dest_ip, &udp_servaddr.sin_addr) == 0)
    {
      perror("The IP address provided is wrong");
      exit(EXIT_FAILURE);
    }
#endif

  /* check if IPv6 */
  if (strstr(dest_ip, ":") != 0)
    udp_servaddr.sin_family = AF_INET6;
  else
    udp_servaddr.sin_family = AF_INET;

  udp_servaddr.sin_port = htons(BOOTLOADER_PORT);

  set_timeout(UDP_TIMEOUT_SEC, UDP_TIMEOUT_USEC);

  /* create the connection */
  if((r = connect(udp_sockfd, (struct sockaddr *) &udp_servaddr , sizeof(udp_servaddr)) != 0))
    {
#if defined(WIN32) || defined(__WIN32__)
      fprintf(stderr, "connect failed: %s\n", sockerr(WSAGetLastError()));
#else
      perror("connection failure");
#endif
      close_socket();
      exit(EXIT_FAILURE);
    }
}

/**
 * @brief request bootloader command
 *
 * @param msg the message to send
 * @param answer if we are expecting an answer
 * @param dest_ip the destination ip of the message
 * @param cmd_type command type that we check in the answer
 *
 * @return if there the returned message is good or not otherwise true
 */
bool
send_msg(bool answer, int cmd_type)
{
  int bytes;

  memset(&msg_back, 0, sizeof(msg_back));
  memset(&udp_buffer, 0, sizeof(udp_buffer));

  /* send request */
  send(udp_sockfd, msg, msg_size, 0);

  if (answer)
    {
      /* receive request */
      bytes = recv(udp_sockfd, udp_buffer, UDP_BUF_LEN, 0);

      /* check if there is a valid response */
      if (bytes == -1 ||
          /* check if the packet is at least 32 bytes */
          bytes < 32 ||
          /* check if the first bytes are the command sent */
          memcmp(udp_buffer, bootloader_cmds[cmd_type], sizeof(bootloader_cmds[cmd_type])) != 0)
        {
          return false;
        }
      else
        {
          memcpy(msg_back, udp_buffer, bytes);
          return true;
        }
    }
  return true;
}

/**
 * @brief test if the device is alive
 *
 * @param print show strings to the user
 *
 * @return true if the device is alive otherwise false
 */
bool
test_device(bool print)
{
  int r;

  memset(msg, 0, sizeof(msg));
  memcpy(msg, bootloader_cmds[1], sizeof(bootloader_cmds[1]));

  r = send_msg(true, 1);

  if(!r)
    {
      if(print)
        perror("Connection error when receiving the data");
      return(false);
    }
  else
    {
      memset(&odyssey2.mac_address, 0, sizeof(odyssey2.mac_address));
      strncpy(odyssey2.mac_address, msg_back+26, 6);
      if(print)
        printf("The MAC address is %02x:%02x:%02x:%02x:%02x:%02x\n",
               (unsigned char) odyssey2.mac_address[0],
               (unsigned char) odyssey2.mac_address[1],
               (unsigned char) odyssey2.mac_address[2],
               (unsigned char) odyssey2.mac_address[3],
               (unsigned char) odyssey2.mac_address[4],
               (unsigned char) odyssey2.mac_address[5]
               );
      return(true);
    }
}

/**
 * @brief check the current_ip if it availble; exit if not
 */
void
check_device()
{
  if(!test_device(false))
    {
      perror("The device is unreachable");
      exit(EXIT_FAILURE);
    }
}

/**
 * @brief reset the FPGA
 *
 * @param print show strings to the user
 *
 * @return true if the command is sent without error
 */
bool
reset_device(bool print)
{
  memset(msg, 0, sizeof(msg));
  memcpy(msg, bootloader_cmds[0], sizeof(bootloader_cmds[0]));
  bool r = send_msg(false, 0);

  if (print && r)
    printf("Reset command sent\n");
  return(true);
}

/**
 * @brief set the new IP
 *
 * @param print show strings to the user
 *
 * @return true if the command is sent without error
 */
bool
change_ip(bool print)
{
  int n = 0;
  char nip[32] = "";
  char *token;
  char *new_ip_tmp = strdup(odyssey2.new_ip);

  if (strstr(new_ip_tmp, ":") != 0)
    {
      while ((token = custom_strsep(&new_ip_tmp, ":")) != NULL)
        {
          nip[n] = atoi(token);
          n++;
        }
    }
  else
    {
      while ((token = custom_strsep(&new_ip_tmp, ".")) != NULL)
        {

          nip[n] = atoi(token);
          n++;
        }
    }

  free(new_ip_tmp);

  memset(msg, 0, sizeof(msg));
  memcpy(msg, bootloader_cmds[2], sizeof(bootloader_cmds[2]));
  if(n <= 16)
    memcpy(msg+(UDP_CMD_LEN-n), nip, n);
  else
    {
      perror("Wrong IP address");
      return(false);
    }

  bool r = send_msg(true, 2);

  if (!r)
    {
      if (print)
        perror("For some reason the change failed. Check the correctness of the addresses");
      return(false);
    }
  else
    {
      if (print)
        printf("The new IP address is %s\n", odyssey2.new_ip);
      return(true);
    }

  return(false);
}

/**
 * @brief erase the flash slot
 *
 * @return true if the erase was done otherwise false
 */
bool
erase_slot(bool print)
{
  int r;

  memcpy(msg, bootloader_cmds[3], sizeof(bootloader_cmds[3]));
  msg[31] = odyssey2.firmware_slot;

  /* we need to change the timeout to wait the erase process to finish */
  set_timeout(UDP_TIMEOUT_SEC*10, UDP_TIMEOUT_USEC);
  r = send_msg(true, 3);
  set_timeout(UDP_TIMEOUT_SEC, UDP_TIMEOUT_USEC);

  if(!r)
    {
      if(print)
        fprintf(stderr, "Erase slot %d failed\n", odyssey2.firmware_slot);
      return(false);
    }
  else
    {
      if(print)
        printf("Slot %d erased\n", odyssey2.firmware_slot);
      return(true);
    }

  return(true);
}

/**
 * @brief write firmware to the device
 *
 * @return true if the write was done otherwise false
 */
bool
write_firmware()
{
  unsigned char chunk[FIRMWARE_CHUNK];
  FILE *fp;
  bool ret = true;

  /* erase the slot */
  if(!erase_slot(false))
    return(false);

  if((fp=fopen(firmware_file, "r")) == NULL)
    {
      perror("fopen");
      exit(EXIT_FAILURE);
    }

  set_timeout(UDP_TIMEOUT_SEC*3, UDP_TIMEOUT_USEC);
  msg_size = UDP_CMD_LEN+FIRMWARE_CHUNK;
  while(fread(chunk, sizeof(unsigned char), FIRMWARE_CHUNK, fp) > 0)
    {
      memset(msg, 0, sizeof(msg));
      memcpy(msg, bootloader_cmds[4], sizeof(bootloader_cmds[4]));
      memcpy(msg+UDP_CMD_LEN, chunk, sizeof(chunk));
      if (send_msg(true, 4) == false)
        {
          ret = false;
          goto WF_RET;
        }
      else
        if(memcmp(msg_back, msg, sizeof(msg)) != 0)
          {
            ret = false;
            goto WF_RET;
          }
    }
  msg_size = UDP_CMD_LEN;
  set_timeout(UDP_TIMEOUT_SEC, UDP_TIMEOUT_USEC);

 WF_RET:
  fclose(fp);
  return(ret);
}

/**
 * @brief print the bootloader status like, version, slot and amplifiers status
 *
 * @param print if text print is enabled
 */
bool
get_status(bool print)
{
  int r, i, v = 0;

  memset(msg, 0, sizeof(msg));
  memcpy(msg, bootloader_cmds[5], sizeof(bootloader_cmds[5]));

  r = send_msg(true, 5);

  if(!r)
    {
      if(print)
        perror("Connection error when receiving the data");
      return(false);
    }
  else
    {
      odyssey2.auto_poweron = (bool) *(msg_back+20);
      odyssey2.audio_amplifier = (bool) *(msg_back+21);
      odyssey2.power_amplifier = (bool) *(msg_back+22);
      odyssey2.firmware_slot = (unsigned short) *(msg_back+23);
      /* bootloader version is 64 bits long and we need to copy only
         the not null characters */
      for (i=0; i < 8; i++)
        if(*(msg_back+24+i) != 0)
          {
            odyssey2.bootloader_version[v] = *(msg_back+24+i);
            v++;
          }
      if(print)
        {
          printf("== Bootloader Status ==\n");
          printf("MAC: %02x:%02x:%02x:%02x:%02x:%02x\n",
                 (unsigned char) odyssey2.mac_address[0],
                 (unsigned char) odyssey2.mac_address[1],
                 (unsigned char) odyssey2.mac_address[2],
                 (unsigned char) odyssey2.mac_address[3],
                 (unsigned char) odyssey2.mac_address[4],
                 (unsigned char) odyssey2.mac_address[5]
                 );
          printf("bootloader version: %s\n", odyssey2.bootloader_version);
          printf("boot slot: %d\n", odyssey2.firmware_slot);
          printf("auto power-on:   %s\n", odyssey2.auto_poweron ? "enabled" : "disabled");
          printf("audio amplifier: %s\n", odyssey2.audio_amplifier ? "enabled" : "disabled");
          printf("power amplifier: %s\n", odyssey2.power_amplifier ? "enabled" : "disabled");
        }
      return(true);
    }
}

/**
 * @brief set the new audio amplifier value: enabled or disabled
 *
 * @param print if text print is enabled
 */
bool
set_audio_amplifier(bool print)
{
  int r;

  memset(msg, 0, sizeof(msg));
  memcpy(msg, bootloader_cmds[6], sizeof(bootloader_cmds[6]));
  msg[UDP_CMD_LEN-1] = (char) odyssey2.audio_amplifier;

  r = send_msg(true, 6);

  if(!r)
    {
      if(print)
        perror("Connection error when receiving the data");
      return(false);
    }
  else
    {
      if(print)
        printf("Now the audio amplifier is: %s\n", odyssey2.audio_amplifier ? "enabled" : "disabled");
      return(true);
    }
}

/**
 * @brief set the new 1W power amplifier value: enabled or disabled
 *
 * @param print if text print is enabled
 */
bool
set_power_amplifier(bool print)
{
  int r;

  memset(msg, 0, sizeof(msg));
  memcpy(msg, bootloader_cmds[7], sizeof(bootloader_cmds[7]));
  msg[UDP_CMD_LEN-1] = (char) odyssey2.power_amplifier;

  r = send_msg(true, 7);

  if(!r)
    {
      if(print)
        perror("Connection error when receiving the data");
      return(false);
    }
  else
    {
      if(print)
        printf("Now the 1W power amplifier is: %s\n", odyssey2.power_amplifier ? "enabled" : "disabled");
      return(true);
    }
}

/**
 * @brief set if the radio should be power on just after the
 *        the power connector is attached
 *
 * @param print if text print es enabled
 */
bool
set_auto_poweron(bool print)
{
  int r;

  memset(msg, 0, sizeof(msg));
  memcpy(msg, bootloader_cmds[10], sizeof(bootloader_cmds[10]));
  msg[UDP_CMD_LEN-1] = (char) odyssey2.auto_poweron;

  r = send_msg(true, 10);

  if(!r)
    {
      if(print)
        perror("Connection error when receiving the data");
      return(false);
    }
  else
    {
      if(print)
        printf("Now the auto power-on functionality is: %s\n", odyssey2.auto_poweron ? "enabled" : "disabled");
      return(true);
    }
}

/**
 * @brief set the slot to boot
 *
 * @param print if text print is enabled
 */
bool
set_boot_slot(bool print)
{
  int r;

  memset(msg, 0, sizeof(msg));
  memcpy(msg, bootloader_cmds[9], sizeof(bootloader_cmds[9]));
  msg[UDP_CMD_LEN-1] = (char) odyssey2.firmware_slot;

  r = send_msg(true, 9);

  if(!r)
    {
      if(print)
        perror("Connection error when receiving the data");
      return(false);
    }
  else
    {
      if(print)
        printf("The new slot to boot is: %d\n", odyssey2.firmware_slot);
      return(true);
    }
}

/**
 * @brief stop at bootloader until the radio is available
 *
 * @param print if text print is enabled
 */
bool
stop_at_bootloader(bool print)
{
  int r=false;
  int i;

  memset(msg, 0, sizeof(msg));
  memcpy(msg, bootloader_cmds[8], sizeof(bootloader_cmds[8]));

  /* we would a fast retry (in usec) */
  set_timeout(0, 200000);

  /* send a packet until timeout */
  for(i=0; i < RETRY_STOP_BOOT; i++)
    {
      printf(">>> retry %d\n", i);
      if(send_msg(true, 8))
        {
          r = 1;
          break;
        }
    }
  set_timeout(UDP_TIMEOUT_SEC, UDP_TIMEOUT_USEC);

  if(!r)
    {
      if(print)
        fprintf(stderr,"No answer from the device");
      return(false);
    }
  else
    {
      if(print)
        printf("Now you can access the bootloader\n");
      return(true);
    }
}

/**
 * @brief when in bootloader start the
 * radio firmware with actual configuration;
 * useful to avoid reboot
 *
 * @param print if text print is enabled
 */
bool
start_radio_firmware(bool print)
{
  int r;

  get_status(false);

  memset(msg, 0, sizeof(msg));
  memcpy(msg, bootloader_cmds[11], sizeof(bootloader_cmds[11]));

  r = send_msg(true, 11);

  if(!r)
    {
      if(print)
        perror("Connection error when receiving the data");
      return(false);
    }
  else
    {
      if(print)
        printf("Radio started with slot %d\n", odyssey2.firmware_slot);
      return(true);
    }
}

/**
 * @brief main function; entry point
 *
 * @return exit signal
 */
int
main(int argc, char **argv)
{
  int c, ret=0;

  /* clear the firmware file string */
  memset(firmware_file, 0, sizeof(firmware_file));

  /* name of the binary */
  bin_name = argv[0];

  if(argc == 1)
    usage();

  /* loop over all of the options */
  while ((c = getopt(argc, argv, "htnpbrsaxzd:e:f:o:g:c:y:")) != -1)
    {
      switch (c)
        {
        case 't':
          argp.test = true;
          break;
        case 'n':
          argp.set = true;
          break;
        case 'p':
          argp.program = true;
          break;
        case 'b':
          argp.stop = true;
          break;
        case 'r':
          argp.reset = true;
          break;
        case 's':
          argp.boot_slot = true;
          break;
        case 'a':
          argp.status = true;
          break;
        case 'x':
          argp.erase = true;
          break;
        case 'z':
          argp.start_radio = true;
          break;
        case 'g':
          odyssey2.power_amplifier = atoi(optarg);
          if(odyssey2.power_amplifier != 0 && odyssey2.power_amplifier != 1)
            {
              fprintf(stderr, "Wrong value. choose 0 or 1\n");
              exit(EXIT_FAILURE);
            }
          argp.pa = true;
          break;
        case 'c':
          odyssey2.audio_amplifier = atoi(optarg);
          if(odyssey2.audio_amplifier != 0 && odyssey2.audio_amplifier != 1)
            {
              fprintf(stderr, "Wrong value. choose 0 or 1\n");
              exit(EXIT_FAILURE);
            }
          argp.aa = true;
          break;
        case 'y':
          odyssey2.auto_poweron = atoi(optarg);
          if(odyssey2.auto_poweron != 0 && odyssey2.auto_poweron != 1)
            {
              fprintf(stderr, "Wrong value. choose 0 or 1\n");
              exit(EXIT_FAILURE);
            }
          argp.poweron = true;
          break;
        case 'd':
          snprintf(odyssey2.current_ip, BUF_LEN, "%s", optarg);
          if(!validate_ip(odyssey2.current_ip))
            {
              fprintf(stderr, "Wrong IP. check it\n");
              exit(EXIT_FAILURE);
            }
          break;
        case 'e':
          snprintf(odyssey2.new_ip, BUF_LEN, "%s", optarg);
          if(!validate_ip(odyssey2.current_ip))
            {
              fprintf(stderr, "Wrong IP. check it\n");
              exit(EXIT_FAILURE);
            }
          break;
        case 'f':
          snprintf(firmware_file, PATH_MAX, "%s", optarg);
          if (strlen(firmware_file) == 0 || access(firmware_file, R_OK) != 0)
            {
              fprintf(stderr, "The file %s doesn't exist or it is not readable\n", firmware_file);
              exit(EXIT_FAILURE);
            }
          if (strstr(firmware_file, FIRMWARE_EXTENSION) == 0)
            {
              fprintf(stderr, "The file has not the right extension; must be %s\n", FIRMWARE_EXTENSION);
              exit(EXIT_FAILURE);
            }
          /* check if the firmware is too big */
          struct stat st;
          stat(firmware_file, &st);
          if (st.st_size > FIRMWARE_MAX_SIZE)
            {
              fprintf(stderr, "The firmware is too big for the device\n");
              exit(EXIT_FAILURE);
            }
          break;
        case 'o':
          odyssey2.firmware_slot = atoi(optarg);
          if (odyssey2.firmware_slot < 0 || odyssey2.firmware_slot > SLOT_NUMS)
            {
              fprintf(stderr, "Slot number is wrong.\n");
              usage();
            }
          break;
        case 'h':
        case '?':
        default:
          usage();
          break;
        }
    }

#if defined(WIN32) || defined(__WIN32__)
  init_socket();
#endif

  create_socket(odyssey2.current_ip);

  /* Stop the device at boot */
  if (argp.stop)
    {
      stop_at_bootloader(true);
    }

  /* Reset the device */
  if (argp.reset)
    {
      check_device();
      printf("We are resetting device %s\n", odyssey2.current_ip);
      reset_device(true);
    }

  /* if we chain actions we need to wait a bit after reset */
  if (argp.reset && (argp.test || argp.set || argp.program || argp.boot_slot || argp.status))
    sleep(WAIT_AFTER_RESET);

  /* Test the device */
  if (argp.test)
    {
      printf("We are testing device %s\n", odyssey2.current_ip);
      if(test_device(true))
        ret=0;
      else
        ret=1;
    }

  /* get the bootloader status */
  if (argp.status)
    {
      check_device();
      if(get_status(true))
        ret=0;
      else
        ret=1;
    }

  /* Set the new IP */
  if (argp.set)
    {
      if (strlen(odyssey2.new_ip) == 0)
        {
          fprintf(stderr,"You need to declare the new IP\n");
          usage();
        }
      check_device();
      printf("We are changing the IP device from %s to %s\n", odyssey2.current_ip, odyssey2.new_ip);
      if(change_ip(true))
        ret=0;
      else
        ret=1;
    }

  /* erase the slot */
  if (argp.erase)
    {
      check_device();
      if(erase_slot(true))
        ret=0;
      else
        ret=1;
    }

  /* Program the device */
  if (argp.program)
    {
      check_device();
      printf("We are writing the firmware %s to slot %d. Please wait..\n", firmware_file, odyssey2.firmware_slot);
      if(write_firmware())
        {
          printf("DONE\n");
          ret=0;
        }
      else
        {
          fprintf(stderr,"An error occurred\n");
          ret=1;
        }
    }

  /* set the new value for power amplifier */
  if (argp.pa)
    {
      check_device();
      if(set_power_amplifier(true))
        ret=0;
      else
        ret=1;
    }

  /* set the new value for audio amplifier */
  if (argp.aa)
    {
      check_device();
      if(set_audio_amplifier(true))
        ret=0;
      else
        ret=1;
    }

  /* set the new value for auto power-on */
  if (argp.poweron)
    {
      check_device();
      if(set_auto_poweron(true))
        ret=0;
      else
        ret=1;
    }

  /* Set the new boot slot */
  if (argp.boot_slot)
    {
      if (odyssey2.firmware_slot == 0) {
        fprintf(stderr,"You can't boot slot 0\n");
        ret=1;
      }
      else
        {
          check_device();
          if(set_boot_slot(true))
            ret=0;
          else
            ret=1;
        }
    }

  if (argp.start_radio)
    {
      check_device();
      if(start_radio_firmware(true))
        ret=0;
      else
        ret=1;
    }

  close_socket();
  return(ret);
}
