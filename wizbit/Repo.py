"""
Represents a wizbit repository.
This is a git repository that only contains a single file.

Regarding path issues:
Paths are passed as two types, a Paths object, called wizpath
or a string representing the relative path from the base dir.
"""
from subprocess import check_call, Popen, PIPE
from os.path import exists, split, abspath, isabs

from wizbit import *
from wizbit import Conf

def _makeRefname (id):
	return "refs/heads/" + id

def _getTreeish(gitdir, ref):
	return Popen (["git-show-ref", ref], env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0].split()[0]

def _commit (gitdir, cfile, parents):
	tree = Popen (["git-write-tree"], env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0].split()[0]
    	command = ["git-commit-tree",tree]
	for parent in parents:
		command = command + ["-p",parent]
	pop = Popen (command, env = {"GIT_DIR":gitdir}, stdin = Popen(["echo"], stdout=PIPE).stdout, stdout = PIPE)
	commit = pop.communicate()[0].split()[0]
	check_call (['git-update-ref', 'refs/heads/master', commit], env = {"GIT_DIR":gitdir})

def create(wizpath, filename):
	gitdir = wizpath.getRepoName(filename)
	check_call (["git-init-db"], env = {"GIT_DIR":gitdir})
	Conf.addRepo(wizpath.getWizconf(), filename)

def add(wizpath, filename):
	gitdir = wizpath.getRepoName(filename)
	check_call (["git-add", filename], env = {"GIT_DIR":gitdir}, cwd=wizpath.getBase())
	_commit(gitdir, wizpath.getWizconf(), [])

def merge(wizpath, filename, refs):
	"""
	Takes a list of references, and commits a file from the index
	that has the parents pointed to by those references. 
	Returns a tuple (New master sha, list of old sha sums ( the parents))
	"""
	gitdir = wizpath.getRepoName(filename)
	#git-add doesn't accept absolute paths. 
	check_call (["git-add", filename], env = {"GIT_DIR":gitdir}, cwd=wizpath.getBase())
	oldheads = [_getTreeish(gitdir, 'refs/heads/' + r) for r in refs]
	master = _getTreeish(gitdir, 'refs/heads/master')
	heads = oldheads + [master]
	ct = _commit(gitdir, wizpath.getWizconf(), heads);
	for h in oldheads:
		Conf.removeHead(wizpath.getWizconf(), h)

def update(wizpath, filename):
	"""
	Updates the file to its new version.
	"""
	gitdir = wizpath.getRepoName(filename)
	#git-add doesn't accept absolute paths. 
	check_call (["git-add", filename], env = {"GIT_DIR":gitdir}, cwd=wizpath.getBase())
	oldhead = _getTreeish(gitdir, 'refs/heads/master')
	_commit(gitdir, wizpath.getWizconf(), [oldhead])

def checkout(wizpath, filename, ref, codir=None):
	gitdir = wizpath.getRepoName(filename)
	codir = codir or wizpath.getCODir(filename)
	print gitdir
	print codir
	print filename
	print ref
	treeish = _getTreeish(gitdir, ref)
	check_call(["git-update-index", "--index-info"],env = {"GIT_DIR":gitdir}, 
			stdin = Popen(["git-ls-tree", "--full-name", "-r", treeish], 
				env = {"GIT_DIR":gitdir}, stdout=PIPE).stdout)
        check_call(["git-checkout-index", "-f", "--"] + [filename], env = {"GIT_DIR":gitdir}, cwd=codir)

def pull(wizpath, filename, host, remotepath, srcId):
	"""
	Pulls from a remote repository, 
	returns any new heads that have to be added to the conf file

	"""
	gitdir = wizpath.getRepoName(filename)
	#Get all remote heads
	remotewizpath = Paths(remotepath)
	srcUrl = host + ':' + remotewizpath.getRepoName(filename)
	remotes = Popen(["git-fetch-pack", "--all", srcUrl], env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0]
	remotes = [r.split() for r in remotes.split('\n') if r and r.split()[1] != 'HEAD']
	#Get all local heads
	heads = Conf.getHeads(wizpath.getWizconf(), filename)
	checkoutFile = True
	for h in heads:
		headish = _getTreeish(gitdir, h)
		newRemoteHead = ""
		for r in remotes:
			remoteref = r[1]
			remotesha = r[0]
			treeish = Popen(["git-merge-base", "--all", headish, remotesha], 
					env = {"GIT_DIR":gitdir}, 
					stdout=PIPE).communicate()[0].strip()
			if treeish == remotesha:
				#Do nothing, our tree already contains this object
				checkoutFile = False
			elif treeish == headish:
				#Head and merge base are the same, 
				#Just update ref
				check_call(["git-update-ref", h, remotesha], env = {"GIT_DIR":gitdir})
			else:
				newRemoteHead = remoteref
		if newRemoteHead:
			if newRemoteHead == 'refs/heads/master':
				refName = _makeRefname(srcId)
			else:
				refName = newRemoteHead
                        check_call(["git-update-ref", refName, remotesha], env = {"GIT_DIR":gitdir})
			Conf.addHead(wizpath.getWizconf(), filename, refName)
	#Special case of an empty repository
	if not heads:
		for r in remotes:
			remoteref = r[1]
			remotesha = r[0]
                        check_call(["git-update-ref", remoteref, remotesha], env = {"GIT_DIR":gitdir})
			Conf.addHead(wizpath.getWizconf(), filename, remoteref)
	if checkoutFile:
		checkout(wizpath, filename, 'refs/heads/master') 

def log(wizpath, filename):
	gitdir = wizpath.getRepoName(filename)
	return Popen (["git-log", "--pretty=raw", "refs/heads/master"], env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0]

def commitInfo(wizpath, filename, commit):
	info = []
	gitdir = wizpath.getRepoName(filename)
	results = Popen(["git-log", "-n1", "--pretty=format:%an%n%aD", commit],
			env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0]
	info.extend([item.strip() for item in results.split('\n')[:2]])
	results = Popen(["git-ls-tree", "-l", commit, filename],
			env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0]
	info.append(int(results.split()[3]))

	return tuple(info)
