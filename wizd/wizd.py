#! /usr/bin/env python 
import sys
import socket
import os
from sharedict import WizbitSharesData
import SimpleXMLRPCServer

WIZBIT_SERVER_PORT = 1221

class WizbitServer():
	def __init__(self):
		self.__sharesData = WizbitSharesData()

	def getShares(self):
		tempDirs = self.__sharesData.getShares()
		return ["%s %s" % (key, value) for key, value in tempDirs.items()]

	def getLastConfSeen(self, uuid):
		return "Not Implemented"

	def setConf(self, uuid, confstring):
		return "Not Implemented"

	def getConf(self, uuid):
		tempDirs = self.__sharesData.getShares()
		dir = tempDirs[uuid]
		file = open(dir + "wizbit.conf", "r")
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
