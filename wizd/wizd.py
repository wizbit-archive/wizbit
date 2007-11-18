#! /usr/bin/env python 
import sys
import socket
import os
import SimpleXMLRPCServer
import gobject
from wizbit import ServicePublisher, ServiceBrowser, defaultShares, Directory
from wizbit import *

class WizbitServer():
    def __init__(self, shares = defaultShares()):
        self._shares = shares

    def getShares(self):
        return self._shares.getShares()

    def getPath(self, uuid):
        shares = self._shares.getShares()
        for id, shareId, directory in shares:
            if uuid == id:
                break
        return directory

    def getLastConfSeen(self, uuid):
        return "Not Implemented"

    def setConf(self, uuid, confstring):
        return "Not Implemented"

    def getConf(self, uuid):
        shares = self._shares.getShares()
        for id, shareId, directory in shares:
            if uuid == id:
                break
        wizpath = Paths(directory)
        file = open(wizpath.getWizconf(), "r")
        conf = file.read()
        file.close()
        return conf

    def pushNotify(self, dirId, remoteShareId, host):
        #For every local directory with the same shareId, pull 
        #from the remote directory
        shares = self._shares.getShares()
        for id, localShareId, directory in shares:
            if localShareId == remoteShareId:
                Directory.pull(directory, dirId, host)

def server_socket_error():
    print "RPC server socket was disconnected, exiting"
    global main_loop
    main_loop.quit()

def server_callback(source, cb_condition, server):
    server.handle_request()


def start_wizbit_server(shares = defaultShares()):
    servinst = WizbitServer(shares)
    server = SimpleXMLRPCServer.SimpleXMLRPCServer(("", 0))
    server.register_instance(servinst)
    server.register_introspection_functions()
    gobject.io_add_watch (server.fileno(), gobject.IO_IN, server_callback, server)
    gobject.io_add_watch (server.fileno(), gobject.IO_HUP | gobject.IO_ERR, server_socket_error)

    sp = ServicePublisher("Wizbit", "_wizbit._tcp", server.server_address[1])
    sb = ServiceBrowser("_wizbit._tcp")


def main(args):
    global main_loop

    start_wizbit_server()

    main_loop = gobject.MainLoop()

    try:
        main_loop.run()
    except KeyboardInterrupt:
        pass

if __name__ == '__main__':
    sys.exit(main(sys.argv))
