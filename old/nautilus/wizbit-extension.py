from urlparse import urlparse
from os.path import exists, split, isdir

import nautilus
from lxml import etree
import gtk, gobject

from wizbit import *
from wizbit import Directory, Repo, Conf

WIZ_CONTROLLED = "wiz-controlled"
WIZ_CONFLICT = "wiz-conflict"

YES = "Yes"
NO = "No"

class WizResolveDialog(gtk.VBox):
    def __init__(self, file):
        gtk.VBox.__init__(self)
        self.infoStore = gtk.ListStore(gobject.TYPE_STRING,
            gobject.TYPE_STRING,
            gobject.TYPE_INT)

        text = gtk.CellRendererText()

        author = gtk.TreeViewColumn('Author', text, text=0)
        date = gtk.TreeViewColumn('Date modified', text, text=1)
        size = gtk.TreeViewColumn('File Size', text, text=2)

        infoView = gtk.TreeView(self.infoStore)

        infoView.append_column(author)
        infoView.append_column(date)
        infoView.append_column(size)
        
        self.pack_start(infoView)
        self.getVersionInfo(file)

    def getVersionInfo(self, file):
        (scheme, netloc, path, params, query, fragment) = urlparse(file.get_uri())

            base = getWizPath(path)
         if base:
            wizpath = Paths(base)
            filename = wizpath.getRelFilename(path)
            heads = Conf.getHeads(wizpath.getWizconf(), filename)
            for head in heads:
                self.infoStore.append(Repo.commitInfo(wizpath, filename, head))

gobject.type_register(WizResolveDialog)

class WizbitExtension(nautilus.ColumnProvider, nautilus.InfoProvider, nautilus.MenuProvider, nautilus.PropertyPageProvider):
    def __init__(self):
        pass

    def get_columns(self):
        return [nautilus.Column("NautilusWizbit::is_controlled_column",
                                WIZ_CONTROLLED,
                                "Wizbit Controlled",
                                "File may be syncronized by Wizbit"),

                nautilus.Column("NautilusWizbit::has_conflict_column",
                                WIZ_CONFLICT,
                                "Wizbit Conflict",
                                "File may have multiple versions that need to be resolved")]

    def resolve_callback(self, menu, file):
    win = gtk.Window()
    (scheme, netloc, path, params, query, fragment) = urlparse(file.get_uri())
    win.set_title(split(path)[1] + "  Wizbit")
    res = WizResolveDialog(file)
    win.add(res)
    win.show_all()

    def create_callback(self, menu, file):
    (scheme, netloc, path, params, query, fragment) = urlparse(file.get_uri())
    Directory.create(path)

    def createall_callback(self, menu, file):
    (scheme, netloc, path, params, query, fragment) = urlparse(file.get_uri())
    Directory.createall(path)

    def add_callback(self, menu, file):
    (scheme, netloc, path, params, query, fragment) = urlparse(file.get_uri())
        base = getWizPath(path)
    wizpath = Paths(base)
    Directory.add(base, path)

    def get_file_items(self, window, files):
    items = []
        if len(files) != 1:
            return
        file = files[0]

        if (file.get_string_attribute(WIZ_CONTROLLED) == YES) and \
           (file.get_string_attribute(WIZ_CONFLICT) == YES):
            item = nautilus.MenuItem('NautilusWizbit:resolve_item',
                                     'Wizbit resolve...',
                                     'Resolve the Wizbit conflict')
            item.connect('activate', self.resolve_callback, file)
            items.append(item)
    if (file.get_string_attribute(WIZ_CONTROLLED) == NO) and \
       (file.is_directory()):
            item = nautilus.MenuItem('NautilusWizbit:create',
                                     'Wizbit create...',
                                     'Create a Wizbit controlled directory')
            item.connect('activate', self.create_callback, file)
            items.append(item)
    if (file.get_string_attribute(WIZ_CONTROLLED) == NO) and \
       (file.is_directory()):
            item = nautilus.MenuItem('NautilusWizbit:createall',
                                     'Wizbit create all...',
                                     'Create a Wizbit controlled directory and add all files')
            item.connect('activate', self.createall_callback, file)
            items.append(item)
    if (file.get_string_attribute(WIZ_CONTROLLED) == NO) and \
       not (file.is_directory()):
            item = nautilus.MenuItem('NautilusWizbit:add',
                                     'Wizbit add...',
                                     'Add file to a Wizbit controlled directory')
            item.connect('activate', self.add_callback, file)
            items.append(item)
    
    return items

    def get_property_pages(self, files):
        if len(files) != 1:
            return
        
        file = files[0]

        if file.is_directory():
            return

        if (file.get_string_attribute(WIZ_CONTROLLED) == YES):
            self.property_label = gtk.Label('Wizbit versions')
            self.property_label.show()

            self.property_page = WizResolveDialog(file)
            self.property_page.show_all()

        return nautilus.PropertyPage("NautilusWizbit::version_page",
                                         self.property_label, self.property_page),

    def update_file_info(self, file):
        controlled = False
        conflict = False

        (scheme, netloc, path, params, query, fragment) = urlparse(file.get_uri())

        if scheme != 'file':
            return
        
        base = getWizPath(path)
        if base:
            if isdir(path):
                controlled = True
            else:
        wizpath = Paths(base)
        filename = wizpath.getRelFilename(path)
        repos = Conf.getRepos(wizpath.getWizconf())
        if filename in repos:
            controlled = True
            heads = Conf.getHeads(wizpath.getWizconf(), filename)
            if len(heads) > 1:
                conflict = True
        if controlled:
            file.add_emblem("cvs-controlled")
            file.add_string_attribute(WIZ_CONTROLLED, YES)
        else:
            file.add_string_attribute(WIZ_CONTROLLED, NO)

        if conflict:
            file.add_emblem("cvs-conflict")
            file.add_string_attribute(WIZ_CONFLICT, YES)
        else:
            file.add_string_attribute(WIZ_CONFLICT, NO)
