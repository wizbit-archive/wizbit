import os
import uuid
import platform

import wizbit
from wizbit import Conf, Repo, Shares

import socket
import xmlrpclib

def _addEmpty(dir, file):
	"""
	Adds an empty git repository to the directory with a particular
	file name. This is needed for adding new files to a directory that
	are subsequently to be pushed to / pulled from a remote repository.
	"""
	wizdir, wizconf = getParams(dir)
	repoName = getRepoName(file)
	try:
		os.mkdir(self.__wizdir + split(file)[0])
	except OSError:
		pass
	gitdir = abspath(self.__wizdir + repoName)
	Repo.create(gitdir)
	Conf.addRepo(wizconf, repoName)

def _pull(dir, host, path, srcId):
	wizdir, wizconf = getParams(newdir)
	repos = Conf.getRepos(wizconf)
	for r in repos:
		rpath = path + r
		Repo.pull(r, wizconf, host, rpath, srcId)

def add(dir, file):
	"""
	Adds an existing file to the wizbit directory.
	"""
	wizdir, wizconf = getParams(dir)
	repoName = getRepoName(file)
	_addEmpty(file)
	ct = Repo.add(repoName)

def update(dir, dirId, srchost, srcpath):
	"""
	Merges a wizbit.conf file. This means looking 
	for the files in the new conf that are not version controlled
	and initialising a repository for them and updating the current
	conf file with the new repositories. 
	Then pulling from the possibly remote repositories
	"""
	#Get the local conf
	wizdir, wizconf = getParams(dir)
	cfile = open(wizconf)
	current = cfile.read()
	cfile.close()

	#Get the remote conf
	srcUrl = getWizUrl(srchost)
	server = xmlrpclib.ServerProxy(srcUrl)
	newconf = server.getConf(dirId)

	curconf = etree.XML(current)
	newconf = etree.XML(new)

	#Get a list of all files in current and new
	currepos = [r.get("name") for r in curconf.xpath("/wizbit/repo")]
	newrepos = [r.get("name") for r in newconf.xpath("/wizbit/repo")]
	diff = [r for r in newrepos if r not in currepos]
	
	#Add empty repositories for any new files
	for file in diff:
		_addEmpty(dir, file.rsplit('.git')[0])

	_pull(dir, srchost, srcpath, dirId):

def clone(dir, dirId, srchost, srcpath):
	"""
	Clones a remote directory by 
	creating a new repository and updating
	from a possibly remote one.
	"""
	wizdir, wizconf = getParams(dir)
	#Get the conf file from the remote host
	srcUrl = getWizUrl(srchost)
	server = xmlrpclib.ServerProxy(srcUrl)
	shareId = Conf.getShareId(srcConf)
	#Create the empty directory and update it
	create(dir, shareId)
	update(dir, dirId, srchost, srcpath)

def create (newdir, shareId=None):
	wizdir, wizconf = getParams(newdir)
	os.makedirs (wizdir)
	shareId = shareId or uuid.uuid4().hex
	Conf.createConf(wizconf, shareId, uuid.uuid4().hex, platform.node())
	Shares.addShare(id.text, wizdir)
