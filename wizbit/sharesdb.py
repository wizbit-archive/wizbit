import gobject
import xmlrpclib
from discovery import ServiceBrowser
from util import getWizUrl
from xmlrpcdeferred import GXMLRPCTransport

class SharesDatabase(gobject.GObject):
    def __init__(self):
        self.sb = ServiceBrowser("_wizbit._tcp")
        self.sb.connect ( "service-found", self._service_found)
        self.sb.connect ( "service-removed", self._service_removed)

        self.shares = {}
        self.names = {}

    def _shares_ready(self, shares, interface, address, port, dir):
        print shares.value
        for dirId, shareId, dir in shares.value:
            if shareId not in self.shares:
                self.shares[shareId] = {}
            self.shares[shareId][dirId] = (interface, address, port, dir)
            if name not in self.names:
                self.names[name] = []
            self.names[name].append((shrId,dirId))


    def _service_found(self, object, name, type, interface, host, address, port):
        print "service found",name, type, interface, host, address, port;
        t = GXMLRPCTransport()
        srcUrl = getWizUrl(address, port)
        server = xmlrpclib.ServerProxy(srcUrl, t)
        shares = server.getShares()
        shares.connect('ready', self._shares_ready, interface, address, port, dir);
    def _service_removed(self, widget, name):
        for shrId, dirId in self.names[name]:
            del self.shares[shrId][dirId]
            if self.shares[shrId] == {}:
                    del self.shares[shrId]


