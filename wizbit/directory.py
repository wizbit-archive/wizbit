from util import getParams, getRepoName, getWizPath, makeRefname
from gitcommand import getOutput
import repo

def addEmpty(dir, file):
	"""
	Adds an empty git repository to the directory with a particular
	file name. This is needed for adding new files to a directory that
	are subsequently to be pushed to / pulled from a remote repository.
	"""
	dir, wizdir, wizconf = getParams(dir)
	repoName = getRepoName(file)
	try:
		os.mkdir(self.__wizdir + split(file)[0])
	except OSError:
		pass
	gitdir = abspath(self.__wizdir + repoName)
	repo.create(gitdir)
	conf.addRepo(wizconf, repoName)

def add(dir, file):
	"""
	Adds an existing file to the wizbit directory.
	"""
	dir, wizdir, wizconf = getParams(dir)
	repoName = getRepoName(file)
	addEmpty(file)
	ct = repo.add(repoName)

def mergeConfs(dir, new):
	"""
	Merges a wizbit.conf file. This means looking 
	for the files in the new conf that are not version controlled
	and initialising a repository for them and updating the current
	conf file with the new repositories. 
	Takes two XML strings. 
	"""
	dir, wizdir, wizconf = getParams(dir)
	cfile = open(self.__wizdir + '/wizbit.conf')
	current = cfile.read()
	cfile.close()
	curtree = etree.XML(current)
	newtree = etree.XML(new)
	#Get a list of all files in current and new
	currepos = [r.get("name") for r in curtree.xpath("/wizbit/repo")]
	newrepos = [r.get("name") for r in newtree.xpath("/wizbit/repo")]
	diff = [r for r in newrepos if r not in currepos]
	
	for file in diff:
		addEmpty(dir, file.rsplit('.git')[0])

def pull(dir, remoteUrl):
	dir, wizdir, wizconf = getParams(dir)

