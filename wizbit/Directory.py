import os
import uuid
import platform

from os.path import split, abspath

from wizbit import *
from wizbit import Conf, Repo, Shares

import socket
import xmlrpclib

def _addEmpty(dirname, filename):
	"""
	Adds an empty git repository to the directory with a particular
	file name. This is needed for adding new files to a directory that
	are subsequently to be pushed to / pulled from a remote repository.
	"""
	wizdir, wizconf = getParams(dirname)
	repoName = getRepoName(dirname, filename)
	try:
		os.mkdir(split(filename)[0])
	except OSError:
		pass
	Repo.create(repoName)
	Conf.addRepo(wizconf, repoName)

def _pull(dirname, host, path, srcId):
	wizdir, wizconf = getParams(newdir)
	repos = Conf.getRepos(wizconf)
	for r in repos:
		rpath = path + r
		Repo.pull(r, wizconf, host, rpath, srcId)

def add(dirname, filename):
	"""
	Adds an existing file to the wizbit directory.
	"""
	dirname = abspath(dirname)
	filename = abspath(filename)
	wizdir, wizconf = getParams(dirname)
	repoName = getRepoName(dirname, filename)
	_addEmpty(dirname, filename)
	Repo.add(repoName, wizconf, filename)

def update(dirname, dirId, srchost):
	"""
	Merges a wizbit.conf file. This means looking 
	for the files in the new conf that are not version controlled
	and initialising a repository for them and updating the current
	conf file with the new repositories. 
	Then pulling from the possibly remote repositories
	"""
	dirname = abspath(dirname)
	#Get the local conf
	wizdir, wizconf = getParams(dirname)
	cfile = open(wizconf)
	current = cfile.read()
	cfile.close()

	#Get the remote conf
	srcUrl = getWizUrl(srchost)
	server = xmlrpclib.ServerProxy(srcUrl)
	srcpath = server.getPath(dirId)
	newconf = server.getConf(dirId)

	curconf = etree.XML(current)
	newconf = etree.XML(new)

	#Get a list of all files in current and new
	currepos = [r.get("name") for r in curconf.xpath("/wizbit/repo")]
	newrepos = [r.get("name") for r in newconf.xpath("/wizbit/repo")]
	diff = [r for r in newrepos if r not in currepos]
	
	#Add empty repositories for any new files
	for file in diff:
		_addEmpty(dirname, file.rsplit('.git')[0])

	_pull(dirname, srchost, srcpath, dirId)

def clone(dirname, dirId, srchost):
	"""
	Clones a remote directory by 
	creating a new repository and updating
	from a possibly remote one.
	"""
	dirname = abspath(dirname)
	wizdir, wizconf = getParams(dirname)
	srcUrl = getWizUrl(srchost)
	server = xmlrpclib.ServerProxy(srcUrl)
	#Get the path to the directory from the 
	#Remote host
	srcpath = server.getPath(dirId)
	#Get the conf file from the remote host
	srcConf = server.getConf(dirId)
	shareId = Conf.getShareId(srcConf)
	#Create the empty directory and update it
	create(dirname, shareId)
	update(dirname, dirId, srchost, srcpath)

def create (newdir, shareId=None):
	newdir = abspath(newdir)
	wizdir, wizconf = getParams(newdir)
	os.makedirs (wizdir)
	shareId = shareId or uuid.uuid4().hex
	dirId = uuid.uuid4().hex
	Conf.createConf(wizconf, shareId, dirId, platform.node())
	Shares.addShare(dirId, wizdir)
	return dirId
