WIZBIT_SERVER_PORT = 3492

def makeRefname (id):
    return "refs/heads/" + id

def getWizUrl(host,port):
	return 'http://%s:%d' % (host, port)

class Paths():
	def __init__(self, base):
		"""
		Takes absolute path to base of wizbit directory.
		"""
		self.__base = base

	def getBase(self):
		return self.__base

	def getWizdir(self):
		return self.__base + '/.wizbit'

	def getWizconf(self):
		return self.__base + '/.wizbit/wizbit.conf'

	def getAbsFilename(self, filename):
		"""
		Takes relative path to file from base directory.
		Returns absolute path to file.
		"""
		return self.__base + '/' + filename

	def getRepoName(self, filename):
		"""
		Takes relative path to file from base directory.
		Returns absolute path to git repository.
		"""
		return self.getWizdir() + '/' + filename + '.git'

	def getRelFilename(self, filename):
		"""
		Takes absolute path to a file and returns the 
		relative path to the file from the base directory.
		"""
		name = filename.split(self.__base)[1]
		if name[0] == '/':
			return name[1:]
		else:
			return name

	def getCODir(self, filename):
		from os.path import split
		return split(self.getAbsFilename(filename))[0]

def getWizPath(path):
	from os.path import exists, split
	if exists(path + "/.wizbit"):	 
		return path
	else:
		(head, tail) = split(path)
		if head != '/':
			return getWizPath(head)
		else:
			if exists("/.wizbit"):
				return head
			else:
				return ""

def isWizdir(path):
	from os.path import split
	head, tail = split(path)
	if head == path:
		return False
	elif tail == '.wizbit':
		return True
	elif head != '/':
		return isWizdir(head)
	else:
		return False
