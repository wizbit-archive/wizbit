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
        self.iconview.show()
        self.window.show()
        self.diricon = gtk.icon_theme_get_default().load_icon(gtk.STOCK_DIRECTORY, 48, gtk.ICON_LOOKUP_USE_BUILTIN)
        self.items = {}



class MountsDialog:

    MOUNT_CANCEL = 1
    MOUNT_SELECT = 1

    def __init__(self):
        gladefile = "wizview.glade"
        windowname = "mounts_dialog"
        self.wTree=gtk.glade.XML (gladefile,windowname)
        self.window = self.wTree.get_widget(windowname)

        self.mountsview = self.wTree.get_widget("mounts_table")
        #liststore has shareid, share name, mountpath, mounted
        self.mounts = gtk.ListStore(str, str, str, 'gboolean')
        self.mountsview.set_model(self.mounts)

        cellpb = gtk.CellRendererPixbuf()
        column = gtk.TreeViewColumn ("Share", cellpb)
        cell = gtk.CellRendererText()
        column.pack_start(cell, False)
        column.set_cell_data_func(cellpb, self._get_dir_icon)
        column.set_attributes(cell, text=1)
        self.mountsview.append_column(column)
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn ("Mount Path", cell)
        column.set_attributes(cell, text=2)

        self.mountsview.connect("cursor_changed", self._cursor_moved);

        self.sdb = SharesDatabase()
        self.sdb.connect ( "updated", self._sdb_updated)

        self.mountsview.append_column(column)
        self.mountsview.show()

        self.wTree.get_widget("mount_share").connect("clicked", self._mount_clicked)
        self.wTree.get_widget("umount_share").connect("clicked", self._umount_clicked)
        self.wTree.get_widget("mount_share").set_sensitive(False)
        self.wTree.get_widget("umount_share").set_sensitive(False)

        self.window.show()
        self.diricon = gtk.icon_theme_get_default().load_icon(gtk.STOCK_DIRECTORY, 16, gtk.ICON_LOOKUP_USE_BUILTIN)
        self.items = {}
        self._fill_local_shares()

    def _fill_local_shares(self):
        for dirId,shrId,path in defaultShares().getShares():
            self.items[shrId] = (shrId, path, True)
        self._populate_list()

    def _get_dir_icon(self, column, cell, model, iter):
        cell.set_property('pixbuf', self.diricon)

    def _sdb_updated(self, sdb):
        pprint(sdb.shares, width=160)
        for s in sdb.shares.keys():
            self.items[s] = (s, None, False)
        self._populate_list()

    def _populate_list(self):
        self.mounts.clear()
        print self.items
        for (shrId, (name, path, mount)) in self.items.items():
            print shrId, name, path, mount
            self.mounts.append([shrId, name, path, mount])

    def _cursor_moved(self, treeview):
        path, column = treeview.get_cursor()
        iter = self.mounts.get_iter(path)
        (mounted,) = self.mounts.get(iter,3)
        print path, mounted
        self.wTree.get_widget("mount_share").set_sensitive(not mounted)
        self.wTree.get_widget("umount_share").set_sensitive(mounted)

    def _mount_clicked(self, button):
        path, column = self.mountsview.get_cursor()
        iter = self.mounts.get_iter(path)
        (name,) = self.mounts.get(iter,1)
        pathchooser = gtk.FileChooserDialog(title="Please choose a folder in which to mount share '%s'" % name, parent = self.window, action= gtk.FILE_CHOOSER_ACTION_SELECT_FOLDER, buttons=(("Cancel", self.MOUNT_CANCEL),("Select", self.MOUNT_SELECT)))
        response = pathchooser.run()
        if response == self.MOUNT_SELECT:
            pass
        pathchooser.hide()
        pathchooser.destroy()
    def _umount_clicked(self, button):
        pass

app = MountsDialog()
gtk.main()
