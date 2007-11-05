import os
from fcntl import flock, LOCK_EX, LOCK_SH

READ = LOCK_SH
WRITE = LOCK_EX

SHARES_PATH = os.environ["HOME"] + "/.wizdirs"

def lockFile(fd, type):
	# Wait forever to obtain the file lock
	obtained = False
	while (not obtained):
		try:
			flock(file, type)
			obtained = True
		except IOError:
			pass

def addShare(uuid, dir):
	shareFile = open(SHARES_PATH, "a")
	lockFile(shareFile, WRITE)
	try:
		shareFile.write("%s %s\n" % (uuid, dir))
	finally:
		shareFile.close()

def removeShare(uuid):
	shareFile = open(SHARES_PATH, "r+")
	lockFile(shareFile, WRITE)
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
	shareFile = open(SHARES_PATH, "r")
	lockFile(shareFile, READ)
	try:
		shares = []
		for line in shareFile:
			if line:
				(id, dir) = line.split()[0:2]
				shares.append((id, dir))
	finally:
		shareFile.close()
	return shares
