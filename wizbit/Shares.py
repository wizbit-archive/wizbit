import os
from fcntl import flock, LOCK_EX 

WIZSHARE_DATA_PATH = os.environ["HOME"] + "/.wizdirs"

def _waitOnFlock(file):
	# Wait forever to obtain the file lock
	obtained = False
	while (not obtained):
		try:
			flock(file, LOCK_EX)
			obtained = True
		except IOError:
			pass

def addShare(uuid, dir):
	shareFile = open(WIZSHARE_DATA_PATH, "a")
	_waitOnFlock(shareFile)
	try:
		shareFile.write("%s %s\n" % (uuid, dir))
	finally:
		shareFile.close()

def removeShare(uuid):
	shareFile = open(WIZSHARE_DATA_PATH, "r+")
	_waitOnFlock(shareFile)
	try:
		input = shareFile.readlines()
		shareFile.seek(0)
		for line in input:
			(lineid, dir) = line.split()[0:2]
			if lineid != uuid:
				shareFile.write(line)
		shareFile.truncate()
	finally:
		shareFile.close()

def getShares():
	shareFile = open(WIZSHARE_DATA_PATH, "r")
	_waitOnFlock(shareFile)
	try:
		shares = []
		for line in shareFile:
			if line:
				(id, dir) = line.split()[0:2]
				shares.append((id, dir))
	finally:
		shareFile.close()
	return shares
