import gobject
import xmlrpclib
from discovery import ServiceBrowser
from util import getWizUrl
from xmlrpcdeferred import GXMLRPCTransport
from server import find_running_server_by_name

class SharesDatabase(gobject.GObject):
    __gsignals__ = {
            'got-new-share': (gobject.SIGNAL_RUN_FIRST, gobject.TYPE_NONE,(gobject.TYPE_STRING,)),
            'got-new-dir': (gobject.SIGNAL_RUN_FIRST, gobject.TYPE_NONE,(gobject.TYPE_STRING,)),
            'updated': (gobject.SIGNAL_RUN_FIRST, gobject.TYPE_NONE,())
            }

    def __init__(self):
        self.__gobject_init__()
        self.sb = ServiceBrowser("_wizbit._tcp")
        self.sb.connect ( "service-found", self._service_found)
        self.sb.connect ( "service-removed", self._service_removed)

        self.shares = {}
        self.names = {}

    def _update_shares (self, shares, name, interface, address, port, dir):
        for dirId, shareId, dir in shares:
            if shareId not in self.shares:
                self.shares[shareId] = {}
                self.emit("got-new-share", shareId)
            if dirId in self.shares[shareId]:
                self.emit("got-new-dir", dirId)
            self.shares[shareId][dirId] = (interface, address, port, dir)
            if name not in self.names:
                self.names[name] = []
            self.names[name].append((shareId,dirId))
        self.emit("updated")


    def _get_shares_done(self, deferred, name, interface, address, port, dir):
        self._update_shares(deferred.value[0], name, interface, address, port, dir)

    def _service_found(self, object, name, type, interface, host, address, port):
        print "service found",name, type, interface, host, address, port;
        #see if this service is local to our process, if so dont xmlrpc!
        server = find_running_server_by_name (name)
        if server:
            shares = server.instance.getShares()
            self._update_shares(shares, name, interface, address,port,dir)
        else:
            t = GXMLRPCTransport()
            srcUrl = getWizUrl(address, port)
            server = xmlrpclib.ServerProxy(srcUrl, t)
            shares = server.getShares()
            shares.connect('ready', self._get_shares_done, name, interface, address, port, dir);

    def _service_removed(self, widget, name):
        for shrId, dirId in self.names[name]:
            del self.shares[shrId][dirId]
            if self.shares[shrId] == {}:
                    del self.shares[shrId]


