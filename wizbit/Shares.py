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
	file = open(WIZSHARE_DATA_PATH, "a")
	_waitOnFlock(file)
	file.write("%s %s\n" % (uuid, dir))
	file.close()

def removeShare(uuid):
	file = open(WIZSHARE_DATA_PATH, "r+")
	_waitOnFlock(file)
	input = file.readlines()
	file.seek(0)
	for line in input:
		(lineid, dir) = line.split()[0:2]
		if lineid != uuid:
			file.write(line)
	file.truncate()
	file.close()
