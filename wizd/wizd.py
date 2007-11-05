#! /usr/bin/env python 
import sys
import socket
import os
import SimpleXMLRPCServer
import gobject
from wizbit import ServicePublisher, ServiceBrowser

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

def server_socket_error():
	print "RPC server socket was disconnected, exiting"
	global main_loop
	main_loop.quit()

def main(args):
	servinst = WizbitServer()
	server = SimpleXMLRPCServer.SimpleXMLRPCServer(("", 0))
	server.register_instance(servinst)
	server.register_introspection_functions()
	gobject.io_add_watch (server.fileno(), gobject.IO_IN, server.handle_request)
	gobject.io_add_watch (server.fileno(), gobject.IO_HUP | gobject.IO_ERR, server_socket_error)

	sp = ServicePublisher("Wizbit", "_wizbit._tcp", server.server_address[1])
	sb = ServiceBrowser("_wizbit._tcp")

	global main_loop
	main_loop = gobject.MainLoop()

	try:
		main_loop.run()
	except KeyboardInterrupt:
		pass

if __name__ == '__main__':
	sys.exit(main(sys.argv))
