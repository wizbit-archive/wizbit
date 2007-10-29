#! /usr/bin/env python 
import sys
import socket
import os
import SimpleXMLRPCServer

WIZBIT_SERVER_PORT = 3492

from wizbit import Shares

class WizbitServer():
	def getShares(self):
		shares = Shares.getShares()
		return ["%s %s" % (id, directory) for (id, directory) in shares]
	
	def getPath(self, uuid):
		shares = Shares.getShares()
		for id, directory in shares:
			if uuid == id:
				break
		return directory

	def getLastConfSeen(self, uuid):
		return "Not Implemented"

	def setConf(self, uuid, confstring):
		return "Not Implemented"

	def getConf(self, uuid):
		shares = Shares.getShares()
		for id, directory in shares:
			if uuid == id:
				break
		file = open(directory + "/wizbit.conf", "r")
		conf = file.read()
		file.close()
		return conf

def main(args):
	servinst = WizbitServer()
	server = SimpleXMLRPCServer.SimpleXMLRPCServer(("localhost", WIZBIT_SERVER_PORT))
	server.register_instance(servinst)	
	server.register_introspection_functions()
	server.serve_forever()

if __name__ == '__main__':
	sys.exit(main(sys.argv))
