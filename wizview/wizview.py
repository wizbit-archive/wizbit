#!/usr/bin/env python

import sys
try:
    import pygtk
    pygtk.require("2.0")
except:
    pass
try:
    import gobject
    import gtk
    import gtk.glade
except:
    sys.exit(1)

import xmlrpclib
from wizbit import ServiceBrowser, getWizUrl

class Wizview:

    def __init__(self):
        gladefile = "wizview.glade"
        windowname = "wizview"
        self.wTree=gtk.glade.XML (gladefile,windowname)
        self.window = self.wTree.get_widget("wizview")
        self.iconview = self.wTree.get_widget("shares")
        self.sharelist = gtk.ListStore(gtk.gdk.Pixbuf, str)
        self.iconview.set_model(self.sharelist)
        self.iconview.set_pixbuf_column(0)
        self.iconview.set_text_column(1)
        self.sd = WizbitDirectory()
        self.sb.connect ( "service-found", self._service_found)
        self.sb.connect ( "service-removed", self._service_removed)
        self.iconview.show()
        self.window.show()
        self.diricon = gtk.icon_theme_get_default().load_icon(gtk.STOCK_DIRECTORY, 48, gtk.ICON_LOOKUP_USE_BUILTIN)
        self.items = {}

    def _service_found(self, widget, name, type, interface, host, address, port):
        print (name, type, interface, host, address, port);

        srcUrl = getWizUrl(address, port)
        server = xmlrpclib.ServerProxy(srcUrl)
        shares = server.getShares()
        print shares

        self.items[name] = self.sharelist.append([self.diricon, host])

    def _service_removed(self, widget, name):
        self.sharelist.remove(self.items[name])
        del self.items[name]

app = Wizview()
gtk.main()
