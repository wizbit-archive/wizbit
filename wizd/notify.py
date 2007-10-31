import os
from fcntl import flock, LOCK_EX 
from threading import Lock
from pyinotify import WatchManager, ThreadedNotifier, EventsCodes, ProcessEvent

def _waitOnFlock(file):
	# Wait forever to obtain the file lock
	obtained = False
	while (not obtained):
		try:
			flock(file, LOCK_EX)
			obtained = True
		except IOError:
			pass

class InotifyProcessor(ProcessEvent):
	def process_default(self, event):
		print 'NOTIFICATION OF INOTIFY EVENT'
		print event.path

class SharesObserver():
	__single = None

	def __init__(self):
		if SharesObserver.__single:
			raise SharesObserver.__single
		SharesObserver.__single = self
		home = os.environ["HOME"]
		self.__wizPath = home + "/.wizdirs"

		self.__shares = []
		self.__loadShares()
		self.__wm = WatchManager()
		self.__wm.add_watch(self.__wizPath, EventsCodes.IN_MODIFY, proc_fun=self.loadShares)
		self.__notifier = ThreadedNotifier(wm, InotifyProcessor(self))
		self.__notifier.setDaemon(True)
		self.__notifier.start()

	def __loadShares(self, event):
		file = open(self.__wizPath, 'r')
		_waitOnFlock(file)
		tempDirs = []
		for line in file:
			(uuid, dir) = line.split()[0:2]
			tempDirs.append((uuid, dir))
		file.close()
		added = [directory for id, directory in tempDirs if directory not in self.__shares]
		removed = [directory for id, directory in self.__shares if directory not in tempDirs]
		for directory in added:
			self.__wm.add_watch(directory, EventCodes.IN_MODIFY, rec=True)
			self.__shares.append(directory)
		for directory in removed:
			self.__wm.rm_watch(directory, rec=True)
			self.__shares.remove(directory)
