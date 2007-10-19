#! /usr/bin/env python 
import sys
import socket
import xmlrpclib

WIZBIT_SERVER_PORT = 1221

def main(args):
	server = xmlrpclib.ServerProxy('http://localhost:%d' % (WIZBIT_SERVER_PORT))
	print server.system.listMethods()
	shares = server.getShares()
	print shares
	for line in shares:
		(uuid, dir) = line.split()[0:2]
		print server.getLastConfSeen(uuid)

if __name__ == '__main__':
	sys.exit(main(sys.argv))
