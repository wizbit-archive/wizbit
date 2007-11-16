import os
from fcntl import flock, LOCK_EX, LOCK_SH


DEFAULT_SHARES_PATH = os.environ["HOME"] + "/.wizdirs"



class Shares:
    def __init__(self, shares_path = DEFAULT_SHARES_PATH):
        self.shares_path = shares_path

    def _lock(self, mode):
        # Wait forever to obtain the file lock
        mode = mode.strip('U')
        if mode == 'r':
            type = LOCK_SH
        else:
            type = LOCK_EX

        obtained = False
        while (not obtained):
            try:
                flock(self._share_file, type)
                obtained = True
            except IOError:
                pass


    def _open (self, mode):
        self._share_file = open(self.shares_path, mode)
        self._lock(mode)

    def _close (self):
        self._share_file.close()

    def addShare(self, dirId, shareId, path):
        self._open('a')
        try:
            self._share_file.write("%s %s %s\n" % (dirId, shareId, path))
        finally:
            self._close()

    def removeShare(self, dirId):
        self._open('r+')
        try:
            input = self._share_file.readlines()
            self._share_file.seek(0)
            for line in input:
                (lineDirId, shrId, path) = line.split()[0:3]
                if lineDirId != dirId:
                    self._share_file.write(line)
            self._share_file.truncate()
        finally:
            self._close()

    def getShares(self):
        self._open('r')
        try:
            shares = []
            for line in self._share_file:
                if line:
                    (dirId, shrId, path) = line.split()[0:3]
                    shares.append((dirId, shrId, path))
        finally:
            self._close()
        return shares


__default_shares = None
def defaultShares():
    global __default_shares
    if __default_shares == None:
        __default_shares = Shares();
    return __default_shares
