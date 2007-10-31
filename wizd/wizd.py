#! /usr/bin/env python 
import sys
import socket
import os
import SimpleXMLRPCServer
from publish import ServicePublisher

WIZBIT_SERVER_PORT = 3492

from wizbit import Shares
from wizbit import *

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
		wizpath = Paths(directory)
		file = open(wizpath.getWizconf(), "r")
		conf = file.read()
		file.close()
		return conf

def main(args):
	servinst = WizbitServer()
	server = SimpleXMLRPCServer.SimpleXMLRPCServer(("", 0))
	server.register_instance(servinst)
	server.register_introspection_functions()
        sp = ServicePublisher("Wizbit", "_wizbit._tcp", server.server_address[1])
        sp.start()  #just love the race condition... CAN PLZ HAV A MANLOOP??
        try:
	    server.serve_forever() #OH RLY?
        except KeyboardInterrupt:
            pass
        finally:
            sp.stop()

if __name__ == '__main__':
	sys.exit(main(sys.argv))
