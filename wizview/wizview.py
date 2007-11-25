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
from pprint import pprint
from wizbit import SharesDatabase, defaultShares

class ShareSelectDialog:
    def __init__(self):
        gladefile = "wizview.glade"
        windowname = "shareselect_dialog"
        self.wTree=gtk.glade.XML (gladefile,windowname)
        self.window = self.wTree.get_widget("wizview")
        self.iconview = self.wTree.get_widget("shares")
        self.sharelist = gtk.ListStore(gtk.gdk.Pixbuf, str)
        self.iconview.set_model(self.sharelist)
        self.iconview.set_pixbuf_column(0)
        self.iconview.set_text_column(1)
        self.sdb = SharesDatabase()
        self.sdb.connect ( "updated", self._updated)
        self.iconview.show()
        self.window.show()
        self.diricon = gtk.icon_theme_get_default().load_icon(gtk.STOCK_DIRECTORY, 48, gtk.ICON_LOOKUP_USE_BUILTIN)
        self.items = {}

    def _updated(self, sdb):
        pprint(sdb.shares, width=160)
        self.sharelist.clear()
        for s in sdb.shares.keys():
            self.sharelist.append([self.diricon, s])



class MountsDialog:

    def __init__(self):
        gladefile = "wizview.glade"
        windowname = "mounts_dialog"
        self.wTree=gtk.glade.XML (gladefile,windowname)
        self.window = self.wTree.get_widget(windowname)
        self.mountsview = self.wTree.get_widget("mounts_table")
        self.mounts = gtk.ListStore(str, str)
        self.mountsview.set_model(self.mounts)
        cellpb = gtk.CellRendererPixbuf()
        column = gtk.TreeViewColumn ("Mounted Share", cellpb)
        cell = gtk.CellRendererText()
        column.pack_start(cell, False)
        column.set_cell_data_func(cellpb, self._get_dir_icon)
        column.set_attributes(cell, text=0)
        self.mountsview.append_column(column)
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn ("Path", cell)
        column.set_attributes(cell, text=1)
        self.mountsview.append_column(column)
        self.mountsview.show()
        self.window.show()
        self.diricon = gtk.icon_theme_get_default().load_icon(gtk.STOCK_DIRECTORY, 16, gtk.ICON_LOOKUP_USE_BUILTIN)
        self.items = {}
        self._fill_local_shares()

    def _fill_local_shares(self):
        for dirId,shrId,path in defaultShares().getShares():
            self.mounts.append([dirId,path])

    def _get_dir_icon(self, column, cell, model, iter):
        cell.set_property('pixbuf', self.diricon)

app = MountsDialog()
gtk.main()
