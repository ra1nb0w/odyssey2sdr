#!/usr/bin/env python3

# A host pgm can send phy skew data which will re-init the phy with the new timings
# ex: python3 setskew.py 192.168.1.202 0x67 0x46 0x07 0x0f
#
# 0x67 is rx-ctl,tx-ctl
# 0x46 is rx-data,tx-data
# 0x07 is rxclk
# 0x0f is txclk
# 0x00 is cmd to set

import sys
import struct
import socket

print()
print("=== set Ethernet skew values ===")
print()

if len(sys.argv) < 7:
    print("use ", str(sys.argv[0]), " with [IP] [0x67] [0x46] [0x07] [0x0f] [0x00]")
    print()
    print("0x67 is rx-ctl,tx-ctl")
    print("0x46 is rx-data,tx-data")
    print("0x07 is rxclk")
    print("0x0f is txclk")
    print("0x00 is command (0x01 to change skew)")
    exit(1)

UDP_PORT=1024
UDP_IP=str(sys.argv[1])
ctl=int(sys.argv[2],16)
data=int(sys.argv[3],16)
rxclk=int(sys.argv[4],16)
txclk=int(sys.argv[5],16)
cmd=int(sys.argv[6],16)

pkt = bytearray(b'\x00\x00\x00\x00\x07')
pkt.append(ctl)
pkt.append(data)
pkt.append(rxclk)
pkt.append(txclk)
pkt.append(cmd)

pkt_str="".join("\\x%02x" % i for i in pkt)
print("package sent:", pkt_str)

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM) # UDP
sock.sendto(pkt, (UDP_IP, UDP_PORT))
sock.close()
