"""
Module containing a wrapper object for the Wizbit configuration file.
"""
from lxml import etree

def _getConf(cfile):
	return etree.parse(cfile)

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

def getDirId(cfile):
	conf = _getConf(cfile)
	dirIdElement = conf.xpath("/wizbit/dirid")[0]
	return dirIdElement.text

def getRepos(cfile):
	"""
	Gets a list of all the repos.
	"""
	conf = _getConf(cfile)
	repoElements = conf.xpath("/wizbit/repo")
	repos = []
	for repoElement in repoElements:
		repos.append(repoElement.attrib["name"])
	return repos

def getRepo(cfile, reponame):
	"""
	Gets all the data from a particular repo.
	(name, file, [(ref, id)])
	"""
	conf = _getConf(cfile)
	try:
		repoElement = conf.xpath("/wizbit/repo[@name=\""+reponame+"\"]")[0]
	except IndexError:
		raise ValueError, "Cannot find named repo"
	heads = []
	headElements = [h for h in repoElement if h.tag=="head"]
	for headElement in headElements:
		ref = headElement.attrib["ref"]
		id = headElement.find("id").text
		heads.append((ref, id))
	return heads

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
	head, id = head
	try:
		repoElement = conf.xpath("/wizbit/repo[@name=\""+reponame+"\"]")[0]
	except IndexError:
		raise ValueError, "Cannot find named repo"
	headElement = etree.SubElement(repoElement, "head", attrib={"ref" : head})
	idElement = etree.SubElement(headElement, "id")
	idElement.text = id
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
		idElement = headElement.find("id")
		if idElement.text == head or headElement.attrib["ref"] == head:
			repoElement.remove(headElement)
			break
	_write(cfile, conf)

def modifyHead(cfile, reponame, head):
	"""
	Takes the name of a reference head and modifies its ID.
	"""
	conf = _getConf(cfile)
	head, id = head
	try:
		repoElement = conf.xpath("/wizbit/repo[@name=\""+reponame+"\"]")[0]
	except IndexError:
		raise ValueError, "Cannot find named repo"
	for headElement in [h for h in repoElement if h.tag=="head"]:
		if headElement.attrib["ref"] == head:
			idElement = headElement.find("id")
			idElement.text = id
			break
	_write(cfile, conf)

def toString(cfile):
	conf = _getConf(cfile)
	return etree.tostring(conf, pretty_print=True)
