from subprocess import check_call, Popen, PIPE
from lxml import etree
from os.path import abspath, exists, split
from os import getcwd

def commitinfo(gitdir, commit, filename):
	info = []
	results = Popen(["git-log", "-n1", "--pretty=format:%an%n%aD", commit],
			env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0]
	info.extend([item.strip() for item in results.split('\n')[:2]])
	
	results = Popen(["git-ls-tree", "-l", commit, "--", filename],
			env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0]
	print results
	info.append(int(results.split()[3]))

	return tuple(info)

def getwizpath(path):
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
