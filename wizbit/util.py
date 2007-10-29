WIZBIT_SERVER_PORT = 3492

def makeRefname (id):
    return "refs/heads/" + id

def getParams(dir):
	return (dir + '/.wizbit/', dir + '/.wizbit/wizbit.conf')

def getRepoName(directory, filename):
	"""
	Takes absolute path to base directory
	and absolute path to file.
	Returns the absolute git directory (repository)
	for the file. 
	"""
	filename = filename.lstrip(directory)
	return directory + '/.wizbit/' + filename + '.git'

def getWizUrl(host):
	return 'http://%s:%d' % (host, WIZBIT_SERVER_PORT)
