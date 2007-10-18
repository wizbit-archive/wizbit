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
	def __init__(self, shares):
		self.__sharesData = shares

	def process_default(self, event):
		self.__sharesData.loadWizDirs()


class WizbitSharesData():
	__single = None

	def __init__(self):
		if WizbitSharesData.__single:
			raise WizbitSharesData.__single
		WizbitSharesData.__single = self
		home = os.environ["HOME"]
		self.__wizPath = home + "/.wizdirs"
		self.__dictLock = Lock()
		self.loadWizDirs()
		wm = WatchManager()
		wm.add_watch(self.__wizPath, EventsCodes.IN_MODIFY)
		self.__notifier = ThreadedNotifier(wm, InotifyProcessor(self))
		self.__notifier.setDaemon(True)
		self.__notifier.start()

	def loadWizDirs(self):
		file = open(self.__wizPath, 'r')
		_waitOnFlock(file)
		tempDirs = {}
		for line in file:
			(uuid, dir) = line.split()[0:2]
			tempDirs[uuid] = dir.strip()
		file.close()
		self.__dictLock.acquire()
		self.__wizDirs = tempDirs
		self.__dictLock.release()

	def getShares(self):
		self.__dictLock.acquire()
		tempDirs = self.__wizDirs
		self.__dictLock.release()
		return tempDirs
