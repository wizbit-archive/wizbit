import os
from fcntl import flock, LOCK_EX, LOCK_SH


DEFAULT_SHARES_PATH = os.environ["HOME"] + "/.wizdirs"

__READ = LOCK_SH
__WRITE = LOCK_EX
def __lockFile(file, type):
    # Wait forever to obtain the file lock
    obtained = False
    while (not obtained):
        try:
            flock(file, type)
            obtained = True
        except IOError:
            pass


class Shares:
    def __init__(self, shares_path = DEFAULT_SHARES_PATH):
        self._shares_path = shares_path

    def _open (self, mode):
        self._share_file = open(self._shares_path, "a")
        _lockFile(self._share_file, mode)

    def _close (self);
        self._share_file.close()

    def addShare(self, dirId, shareId, dir):
        self._open(__WRITE)
        try:
            self._share_file.write("%s %s %s\n" % (dirId, shareId, dir))
        finally:
            self._close()

    def removeShare(uuid):
        self._open(__WRITE)
        try:
            input = self._share_file.readlines()
            self._share_file.seek(0)
            for line in input:
                (lineid, shrId, dir) = line.split()[0:3]
                if lineid != uuid:
                    self._share_file.write(line)
            shareFile.truncate()
        finally:
            self._close()

    def getShares():
        self._open(__READ)
        try:
            shares = []
            for line in self._share_file:
                if line:
                    (id, shrId, dir) = line.split()[0:3]
                    shares.append((id, shrId, dir))
        finally:
            self._close()
        return shares

def defaultShares():
    global __default_shares
    if not __default_shares:
        __default_shares = Shares();
    return __default_shares
