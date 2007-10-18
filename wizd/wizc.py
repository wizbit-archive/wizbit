#! /usr/bin/env python 
import sys
import socket
import xmlrpclib

WIZBIT_SERVER_PORT = 1221

def main(args):
	server = xmlrpclib.ServerProxy('http://localhost:%d' % (WIZBIT_SERVER_PORT))
	print server.system.listMethods()
	print server.getShares()

if __name__ == '__main__':
	sys.exit(main(sys.argv))
