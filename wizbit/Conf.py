"""
Module containing a wrapper object for the Wizbit configuration file.
"""
from lxml import etree

def _getConf(cfile):
	return etree.parse(cfile)

def _getStringConf(cstring):
	return etree.XML(cstring)

def _write(cfile, conf):
        conf.write (cfile, pretty_print=True, encoding="utf-8", xml_declaration=True)

def createConf(cfile, shareId, dirId, machine):
	root = etree.Element("wizbit")
	conf = etree.ElementTree(root)
	shareIdElement = etree.SubElement(root, "shareid")
	shareIdElement.text = shareId
	dirIdElement = etree.SubElement(root, "dirid")
	dirIdElement.text = dirId
	machineElement = etree.SubElement(root, "machine")
	machineElement.text = machine
	_write(cfile, conf)

def getShareId(cfile):
	conf = _getConf(cfile)
	shareIdElement = conf.xpath("/wizbit/shareid")[0]
	return shareIdElement.text

def getRemoteShareId(cstring):
	conf = _getStringConf(cstring)
	shareIdElement = conf.xpath("/wizbit/shareid")[0]
	return shareIdElement.text

def getDirId(cfile):
	conf = _getConf(cfile)
	dirIdElement = conf.xpath("/wizbit/dirid")[0]
	return dirIdElement.text

def getRemoteDirId(cstring):
	conf = _getStringConf(cstring)
	dirIdElement = conf.xpath("/wizbit/dirid")[0]
	return dirIdElement.text

def _getRepos(conf):
	repoElements = conf.xpath("/wizbit/repo")
	repos = []
	for repoElement in repoElements:
		repos.append(repoElement.attrib["name"])
	return repos

def _getHeads(conf, reponame):
	try:
		repoElement = conf.xpath("/wizbit/repo[@name=\""+reponame+"\"]")[0]
	except IndexError:
		raise ValueError, "Cannot find named repo"
	heads = []
	headElements = [h for h in repoElement if h.tag=="head"]
	for headElement in headElements:
		ref = headElement.attrib["ref"]
		heads.append(ref)
	return heads

def getHeads(cfile, reponame):
	"""
	Gets all the heads data from a particular repo.
	"""
	conf = _getConf(cfile)
	return _getHeads(conf, reponame)

def getRepos(cfile):
	"""
	Gets a list of all the repos.
	"""
	conf = _getConf(cfile)
	return _getRepos(conf)

def getRemoteHeads(cstring, reponame):
	"""
	Gets all the heads data from a particular repo.
	"""
	conf = _getRemoteConf(cstring)
	return _getHeads(conf, reponame)

def getRemoteRepos(cstring):
	"""
	Gets a list of all the repos.
	"""
	conf = _getRemoteConf(cstring)
	return _getRepos(conf)

def addRepo(cfile, file, head=None):
	"""
	Adds a repository to the conf file.

	This consists of a git directory, that is the repository name,
	along with a file, which the git directory is version controlling. 
	"""
	conf = _getConf(cfile)
	repoElement = etree.SubElement(conf.getroot(), "repo", attrib={"name" : file})
	_write(cfile, conf)
	if head:
		addHead(cfile, file, head)

def addHead(cfile, reponame, head):
	"""
	Takes a repository in the conf file and adds the head tuple (ref, id)
	"""
	conf = _getConf(cfile)
	try:
		repoElement = conf.xpath("/wizbit/repo[@name=\""+reponame+"\"]")[0]
	except IndexError:
		raise ValueError, "Cannot find named repo"
	headElement = etree.SubElement(repoElement, "head", attrib={"ref" : head})
	_write(cfile, conf)

def removeHead(cfile, reponame, head):
	"""
	Takes a repository and head name, that can either be the ref or the id and 
	removes the head that they point to.
	"""
	conf = _getConf(cfile)
	try:
		repoElement = conf.xpath("/wizbit/repo[@name=\""+reponame+"\"]")[0]
	except IndexError:
		raise ValueError, "Cannot find named repo"
	for headElement in [h for h in repoElement if h.tag=="head"]:
		if headElement.attrib["ref"] == head:
			repoElement.remove(headElement)
			break
	_write(cfile, conf)

def toString(cfile):
	conf = _getConf(cfile)
	return etree.tostring(conf, pretty_print=True)
