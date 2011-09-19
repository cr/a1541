#!/usr/bin/env python

from d64 import D64Disk
import serial
import sys

d = D64Disk( sys.argv[1] )
dir = d.directory()
print dir

UsbDevice = "/dev/tty.usbserial-A6006jDP"
port = serial.Serial( UsbDevice, 115200, timeout=10 )

while 1:
	cmd = port.read()
	if cmd == 'f': # read file
		name = ""
		byte = ord( port.read() )
		while byte != 0:
			name += chr( byte )
		port.read() # skip CR
		print "cmd:", cmd, "name:", name
		#data = d.read_file( name )
		data = [ 0x01, 0x08, 0x0e, 0x08, 0x00, 0x00, 0x99, 0x22, 0x48, 0x45, 0x4c, 0x4c, 0x4f, 0x22, 0x00, 0x00, 0x00 ]
		port.send( 0 ) # status ok
		i = 0
		while i < len( data ):
			len = ord( port.read() )
			print "len:", len
			while len > 0 and i < len( data ):
				port.write( data[i] )
		port.write( 0 )
		port.write( 0 )

	elif cmd == 'b': # read block
		continue
	elif cmd == 'F': # save file
		continue
	elif cmd == 'B': # write block
		continue
	elif cmd == 'd': # debug info
		data = 0
		while data != 10:
			data = ord( port.read() )
			sys.stdout.write( chr( data ) )
	elif not cmd:
		continue
	else:
		print "unknown serial command", ord( cmd )

port.close()
