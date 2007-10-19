import sys
import os
from lxml import etree
from os.path import abspath, exists, split
from subprocess import call, check_call, Popen, PIPE

def makerepo(dir, file):
	wizdir = dir + "/.wizbit/"
	try:
		os.mkdir(wizdir + split(file)[0])
	except OSError:
		pass
	gitdir = abspath(wizdir + file + ".git")
	check_call (["git-init-db"], env = {"GIT_DIR":gitdir}, cwd=dir)

	wizbitconf = etree.parse (wizdir + "wizbit.conf")

	myid = wizbitconf.find("myid").text

	newrepo = etree.SubElement(wizbitconf.getroot(), "repo", attrib={"name":file+".git"})
	fileel = etree.SubElement(newrepo, "file")
	fileel.text = file

	wizbitconf.write (wizdir + "wizbit.conf", pretty_print=True, encoding="utf-8", xml_declaration=True)

def mergeconfs(current, new, dir):
	"""
	Merges a wizbit.conf file. This means looking 
	for the files in the new conf that are not version controlled
	and initialising a repository for them and updating the current
	conf file with the new repositories. 
	Takes two XML strings. 
	"""
	curtree = etree.XML(current)
	newtree = etree.XML(new)
	#Get a list of all files in current and new
	currepos = [r.get("name") for r in curtree.xpath("/wizbit/repo")]
	newrepos = [r.get("name") for r in newtree.xpath("/wizbit/repo")]
	diff = [r for r in newrepos if r not in currepos]
	
	for file in diff:
		makerepo(dir, file.rsplit('.git')[0])
