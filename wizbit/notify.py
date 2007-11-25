import os
from pyinotify import WatchManager, Notifier, ThreadedNotifier, EventsCodes, ProcessEvent

from wizbit import *
from wizbit import Repo, Directory, defaultShares
import gnotifier

import gobject

class InotifyProcessor(ProcessEvent):
    def process_IN_CLOSE_WRITE(self, event):
        if not isWizdir(event.path):
            print 'CLOSE_WRITE', os.path.join(event.path, event.name)
            if event.name:
                path = os.path.join(event.path, event.name)
                base = getWizPath(path)
                wizpath = Paths(base)
                filename = wizpath.getRelFilename(path)
                if Repo.update(wizpath, filename):
                    #Push to others of the same shares
                    pass

    def process_IN_CREATE(self, event):
        if not isWizdir(event.path):
            print 'CREATE', os.path.join(event.path, event.name)
            if event.name:
                path = os.path.join(event.path, event.name)
                base = getWizPath(path)
                if Directory.add(base, path):
                    #Push to others of the same shares
                    pass
            #What is going on here? Do we track dirs??

    def process_IN_DELETE(self, event):
        if not isWizdir(event.path):
            print 'DELETE', os.path.join(event.path, event.name)
            if event.name:
                path = os.path.join(event.path, event.name)
                base = getWizPath(path)
                wizpath = Paths(base)
                filename = wizpath.getRelFilename(path)
                if Repo.remove(wizpath, filename):
                    #Push to others of the same shares
                    pass


    def process_default(self, event):
        if not isWizdir(event.path):
            #print event.event_name, os.path.join(event.path, event.name)
            pass

class SharesObserver(gobject.GObject):
    """
    Watches all shares directories using pyinotify.
    """

    def __init__(self, shares = defaultShares()):
                self.__shares = shares
        self.__directories = []
        self.__wm = WatchManager()
        self.__loadShares(EventsCodes.IN_CLOSE_WRITE)
        print "watching", shares.shares_path
        self.__wm.add_watch(shares.shares_path, EventsCodes.IN_CLOSE_WRITE, proc_fun=self.__loadShares)
        self.__notifier = gnotifier.GNotifier(self.__wm)

    def __loadShares(self, event):
                print "loadshares"
        shares = self.__shares.getShares()
        added = [directory for id, shrId, directory in shares if directory not in self.__directories]
        tempDirs = [directory for id, shrId, directory in shares]
        removed = [directory for directory in self.__directories if directory not in tempDirs]
        for directory in added:
                        print "adding directory:", directory
            self.__wm.add_watch(directory, EventsCodes.ALL_EVENTS, rec=True, auto_add=True)
            self.__directories.append(directory)
        for directory in removed:
                        print "removing directory:", directory
            self.__wm.rm_watch(directory, rec=True)
            self.__directories.remove(directory)
                print self.__directories
                return True

if __name__ == '__main__':
    obs = SharesObserver()
    mainloop = gobject.MainLoop()
    try:
        mainloop.run()
    except KeyboardInterrupt:
        pass
