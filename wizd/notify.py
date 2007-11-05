import os
from pyinotify import WatchManager, Notifier, ThreadedNotifier, EventsCodes, ProcessEvent

from wizbit import *
from wizbit import Repo, Directory, Shares
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

class SharesObserver():
	"""
	Watches all shares directories using pyinotify.
	"""
	__single = None

	def __init__(self):
		if SharesObserver.__single:
			raise SharesObserver.__single
		SharesObserver.__single = self
		home = os.environ["HOME"]

		self.__shares = []
		self.__wm = WatchManager()
		self.__loadShares(EventsCodes.IN_MODIFY)
		self.__wm.add_watch(Shares.SHARES_PATH, EventsCodes.IN_MODIFY, proc_fun=self.__loadShares)
		self.__notifier = gnotifier.GNotifier(self.__wm, InotifyProcessor())

	def __loadShares(self, event):
		file = open(Shares.SHARES_PATH, 'r')
		Shares.lockFile(file, Shares.READ)
		tempDirs = []
		for line in file:
			(uuid, dir) = line.split()[0:2]
			tempDirs.append((uuid, dir))
		file.close()
		added = [directory for id, directory in tempDirs if directory not in self.__shares]
		tempDirs = [directory for id, directory in tempDirs]
		removed = [directory for directory in self.__shares if directory not in tempDirs]
		for directory in added:
			self.__wm.add_watch(directory, EventsCodes.ALL_EVENTS, rec=True, auto_add=True)
			self.__shares.append(directory)
		for directory in removed:
			self.__wm.rm_watch(directory, rec=True)
			self.__shares.remove(directory)

if __name__ == '__main__':
	obs = SharesObserver()
	mainloop = gobject.MainLoop()
	try:
		mainloop.run()
	except KeyboardInterrupt:
		pass
