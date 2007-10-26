WIZBIT_SERVER_PORT = 1221

def makeRefname (id):
    return "refs/heads/" + id

def getParams(dir):
	return (dir + '/.wizbit', dir + '/.wizbit/wizbit.conf')

def getRepoName(file):
	return file + '.git'

def getFileName(repoName):
	from os.path import split
	name = repoName.rsplit('.git')[0]
	return split(name)[1]

def getWizUrl(host):
	return 'http://%s:%d' % (host, WIZBIT_SERVER_PORT)
