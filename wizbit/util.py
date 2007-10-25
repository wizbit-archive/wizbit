def makeRefname (id):
    return "refs/heads/" + id

def getParams(dir):
	return (dir, dir + '/.wizbit', dir + '/.wizbit/wizbit.conf')

def getRepoName(file):
	return file + '.git'

def getFileName(repoName):
	return repoName.rsplit('.git')[0]

def getWizPath(path):
	from os.path import exists, split
	if exists(path + "/.wizbit"):	 
		return path
	else:
		(head, tail) = split(path)
		if head != '/':
			return getwizpath(head)
		else:
			if exists("/.wizbit"):
				return head
			else:
				return ""
