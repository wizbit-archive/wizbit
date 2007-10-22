"""
Module containing a wrapper object for the Wizbit configuration file.
"""
from lxml import etree

class WizbitConf():
	"""
	Access object for the wizbit configuration file.

	@param file - (string) Conf file to be opened or created
	@param shareId - (string) Unique id of the shared directory 
	@param dirId - (string) Unique id of a particular instance of the shared directory

	If file is opened, shareId and dirId are ignored. 
	If file is to be created shareId and dirId must be provided
	"""
	def __init__(self, file, shareId=None, dirId=None, machine=None):
		self.__file = file
		try:
			self.__conf = etree.parse(file)
		except IOError:
			if not (shareId and dirId and machine):
				raise ValueError, "When creating wizbit directory must \
provide shareId, dirId and machine values"
			root = etree.Element("wizbit")
			self.__conf = etree.ElementTree(root)
			shareIdElement = etree.SubElement(root, "shareid")
			shareIdElement.text = shareId
			dirIdElement = etree.SubElement(root, "dirid")
			dirIdElement.text = dirId
			machineElement = etree.SubElement(root, "machine")
			machineElement.text = machine

	def getShareId(self):
		shareIdElement = self.__conf.xpath("/wizbit/shareid")[0]
		return shareIdElement.text

	def getDirId(self):
		dirIdElement = self.__conf.xpath("/wizbit/dirid")[0]
		return dirIdElement.text

	def getRepos(self):
		"""
		Gets a list of all the repos.
		"""
		repoElements = self.__conf.xpath("/wizbit/repo")
		for repoElement in repoElements:
			yield repoElement.attrib["name"]

	def getRepo(self, reponame):
		"""
		Gets all the data from a particular repo.
		(name, file, [(ref, id)])
		"""
		try:
			repoElement = self.__conf.xpath("/wizbit/repo[@name=\""+reponame+"\"]")[0]
		except IndexError:
			raise ValueError, "Cannot find named repo"
		name = repoElement.attrib["name"]
		file = repoElement.find("file").text
		heads = []
		headElements = [h for h in repoElement if h.tag=="head"]
		for headElement in headElements:
			ref = headElement.attrib["ref"]
			id = headElement.find("id").text
			heads.append((ref, id))
		return (name, file, heads)

	def addRepo(self, file, head=None):
		"""
		Adds a repository to the conf file.

		This consists of a git directory, that is the repository name,
		along with a file, which the git directory is version controlling. 
		"""
		repoElement = etree.SubElement(self.__conf.getroot(), "repo", attrib={"name" : file + ".git"})
		fileElement = etree.SubElement(repoElement, "file")
		fileElement.text = file
		if head:
			self.addHead(file + ".git", head)

	def addHead(self, reponame, head):
		"""
		Takes a repository in the conf file and adds the head tuple (ref, id)
		"""
		head, id = head
		try:
			repoElement = self.__conf.xpath("/wizbit/repo[@name=\""+reponame+"\"]")[0]
		except IndexError:
			raise ValueError, "Cannot find named repo"
		headElement = etree.SubElement(repoElement, "head", attrib={"ref" : head})
		idElement = etree.SubElement(headElement, "id")
		idElement.text = id

	def removeHead(self, reponame, head):
		"""
		Takes a repository and head name, that can either be the ref or the id and 
		removes the head that they point to.
		"""
		try:
			repoElement = self.__conf.xpath("/wizbit/repo[@name=\""+reponame+"\"]")[0]
		except IndexError:
			raise ValueError, "Cannot find named repo"
		for headElement in [h for h in repoElement if h.tag=="head"]:
			idElement = headElement.find("id")
			if idElement.text == head or headElement.attrib["ref"] == head:
				repoElement.remove(headElement)
				break

	def flush(self):
		"""
		Writes the contents of the XML tree to the conf file.
		"""
		self.__conf.write (self.__file, pretty_print=True, encoding="utf-8", xml_declaration=True)

	def __del__(self):
		self.__conf.write (self.__file, pretty_print=True, encoding="utf-8", xml_declaration=True)

	def __str__(self):
		return etree.tostring(self.__conf, pretty_print=True)
