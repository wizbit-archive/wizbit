"""
Represents a wizbit repository.
This is a git repository that only contains a single file.
"""
from subprocess import check_call, Popen, PIPE
from os.path import exists, split, abspath
from util import getFileName

import conf

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
	conf.modifyHead(cfile, gitdir, ('refs/heads/master', commit))

def create(gitdir):
	check_call (["git-init-db"], env = {"GIT_DIR":gitdir})

def add(gitdir, cfile):
	check_call (["git-add", getFileName(gitdir)], env = {"GIT_DIR":gitdir})
	conf.addRepo(cfile, gitdir)
	_commit(gitdir, cfile, [])

def mergeCommit(gitdir, cfile, refs):
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
		conf.removeHead(cfile, h)
	return (ct, heads)

def update(gitdir, cfile):
	"""
	Updates the file to its new version.
	Returns the new Sha
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

def pull(gitdir, fromurl, fromref):
	"""
	Pulls from a remote repository, 
	returns any new heads that have to be added to the conf file
	"""
	heads = Popen(["git-fetch-pack", "--all", fromurl], env = {"GIT_DIR":togitdir}, stdout=PIPE).communicate()[0]
	heads = heads.split()[:-1]
	newHeads = {}
	for ref in heads:
		ref = ref.split()
		remoteref = ref[1]
		remotesha = ref[0]
		if remoteref == 'refs/heads/master':
			headish = _getTreeish(gitdir, 'refs/heads/master')
			baseish = Popen(["git-merge-base", "--all", headish, remotesha], 
					env = {"GIT_DIR":gitdir}, 
					stdout=PIPE).communicate()[0].strip()
			if headish == baseish:
				#Head and merge base are the same, 
				#Just update master ref.
				getOutput('git-update-ref refs/heads/master ' + remotesha, gitdir)
				check_call(["git-update-ref","refs/heads/master", remotesha], env = {"GIT_DIR":gitdir})
			else:
				check_call(["git-update-ref", fromref, remotesha], env = {"GIT_DIR":gitdir})
				newHeads[fromref] = remotesha
		elif remoteref.startswith('refs/heads'):
			getOutput('git-update-ref %s %s' % (fromref, remotesha), gitdir)
                        check_call(["git-update-ref", fromref, remotesha], env = {"GIT_DIR":gitdir})
			newHeads[fromref] = remotesha
	return newHeads

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
