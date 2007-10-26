"""
Represents a wizbit repository.
This is a git repository that only contains a single file.
"""
from subprocess import check_call, Popen, PIPE
from os.path import exists, split, abspath
from util import getFileName

import wizbit
from wizbit import Conf

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

def create(gitdir):
	check_call (["git-init-db"], env = {"GIT_DIR":gitdir})

def add(gitdir, cfile):
	check_call (["git-add", getFileName(gitdir)], env = {"GIT_DIR":gitdir})
	Conf.addRepo(cfile, gitdir)
	_commit(gitdir, cfile, [])

def merge(gitdir, cfile, refs):
	"""
	Takes a list of references, and commits a file from the index
	that has the parents pointed to by those references. 
	Returns a tuple (New master sha, list of old sha sums ( the parents))
	"""
	check_call (["git-add", "-u"], env = {"GIT_DIR":gitdir})
	oldheads = [_getTreeish('refs/heads/' + r) for r in refs]
	master = _getTreeish('refs/heads/master')
	heads = oldheads + [master]
	ct = _commit(gitdir, cfile, heads);
	for h in oldheads:
		Conf.removeHead(cfile, h)

def update(gitdir, cfile):
	"""
	Updates the file to its new version.
	"""
	check_call (["git-add", getFileName(gitdir)], env = {"GIT_DIR":gitdir})
	oldhead = _getTreeish(gitdir, 'refs/heads/master')
	_commit (gitdir, cfile, [oldhead])

def checkout(gitdir, ref, codir):
	treeish = _getTreeish(gitdir, ref)
	check_call(["git-update-index", "--index-info"],env = {"GIT_DIR":gitdir}, 
			stdin = Popen(["git-ls-tree", "--full-name", "-r", treeish], 
				env = {"GIT_DIR":gitdir}, stdout=PIPE).stdout)
	gitdir = abspath(gitdir)
        check_call(["git-checkout-index", "-f", "--"] + [getFileName(gitdir)], env = {"GIT_DIR":gitdir}, cwd=codir)

def _makeRefname (id):
	return "refs/heads/" + id

def pull(gitdir, cfile, host, path, srcId):
	"""
	Pulls from a remote repository, 
	returns any new heads that have to be added to the conf file
	"""
	#Get all remote heads
	srcUrl = host + ':' + path
	remotes = Popen(["git-fetch-pack", "--all", srcUrl], env = {"GIT_DIR":togitdir}, stdout=PIPE).communicate()[0]
	remotes = heads.split()[:-1]
	#Get all local heads
	heads = Conf.getHeads(cfile, gitdir)
	for h in heads:
		headish = _getTreeish(gitdir, h)
		addBranch = False
		for r in remotes:
			remoteref = r[1]
			remotesha = r[0]
			treeish = Popen(["git-merge-base", "--all", headish, remotesha], 
					env = {"GIT_DIR":gitdir}, 
					stdout=PIPE).communicate()[0].strip()
			if treeish == remotesha:
				#Do nothing, our tree already contains this object
				pass
			elif treeish == headish:
				#Head and merge base are the same, 
				#Just update ref
				check_call(["git-update-ref", h, remotesha], env = {"GIT_DIR":gitdir})
			else:
				addBranch = True
		if addBranch:
			if r == 'refs/heads/master':
				refName = _makeRefname(srcId)
			else:
				refname = r
                        check_call(["git-update-ref", refName, remotesha], env = {"GIT_DIR":gitdir})
			Conf.addHead(cfile, gitdir, refName)

def log(gitdir):
	return Popen (["git-log", "--pretty=raw", "refs/heads/master"], env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0]

def commitInfo(gitdir, commit):
	info = []
	results = Popen(["git-log", "-n1", "--pretty=format:%an%n%aD", commit],
			env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0]
	info.extend([item.strip() for item in results.split('\n')[:2]])
	results = Popen(["git-ls-tree", "-l", commit, getFileName(gitdir)],
			env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0]
	info.append(int(results.split()[3]))

	return tuple(info)
