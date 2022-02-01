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
print("=== set TX PLL phase value ===")
print()

if len(sys.argv) < 4:
    print("use ", str(sys.argv[0]), " with [IP] [PHASE_VAL] [CMD]")
    print()
    print("PHASE_VAL:")
    print("\t0x00 if you don't set the value otherwise the HEX value")
    print()
    print("CMD:")
    print("\t0x00 : 1 step down")
    print("\t0x01 : 1 step up")
    print("\t0x02 : set with PHASE_VAL")
    print("\t0x03 : reset")
    print()
    print("1 step is 4.5 degrees of phase")
    exit(1)

UDP_PORT=1024
UDP_IP=str(sys.argv[1])
phaseval=int(sys.argv[2],16)
cmd=int(sys.argv[3],16)

pkt = bytearray(b'\x00\x00\x00\x00\x06')
pkt.append(phaseval)
pkt.append(cmd)

pkt_str="".join("\\x%02x" % i for i in pkt)
print("package sent:", pkt_str)

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM) # UDP
sock.sendto(pkt, (UDP_IP, UDP_PORT))
sock.close()
