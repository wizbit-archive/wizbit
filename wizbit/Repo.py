"""
Represents a wizbit repository.
This is a git repository that only contains a single file.
"""
from subprocess import check_call, Popen, PIPE
from os.path import exists, split, abspath, isabs

import wizbit
from wizbit import Conf

"""
Regarding path issues:
	All functions in this module need absolute paths with the following exceptions,
	Checkout & CommitInfo. The filename param for these functions requires and INDEX RELATIVE
	path. This is almost certainly the path relative to the wizbit base directory.

	Also the Conf.addRepo function takes a path relative to the wizbit base directory.
"""

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

def create(gitdir, cfile, filename):
	"""
	filename - Relative path from the base directory to the file
	           to be added.
	"""
	check_call (["git-init-db"], env = {"GIT_DIR":gitdir})
	Conf.addRepo(cfile, filename + '.git')

def add(gitdir, cfile, base, filename):
	"""
	base - The wizbit base directory
	filename - Relative path from the base directory to the file
	           to be added.
	"""
	#TODO reduce the params to this, make more like merge
	#git-add doesn't accept absolute paths. 
	check_call (["git-add", filename], env = {"GIT_DIR":gitdir}, cwd=base)
	_commit(gitdir, cfile, [])

def merge(gitdir, cfile, filename, refs):
	"""
	Takes a list of references, and commits a file from the index
	that has the parents pointed to by those references. 
	Returns a tuple (New master sha, list of old sha sums ( the parents))
	"""
	#git-add doesn't accept absolute paths. 
	if isabs(filename):
		filename = filename.lstrip('/')
		check_call (["git-add", filename], env = {"GIT_DIR":gitdir}, cwd='/')
	else:
		check_call (["git-add", filename], env = {"GIT_DIR":gitdir})
	oldheads = [_getTreeish('refs/heads/' + r) for r in refs]
	master = _getTreeish('refs/heads/master')
	heads = oldheads + [master]
	ct = _commit(gitdir, cfile, heads);
	for h in oldheads:
		Conf.removeHead(cfile, h)

def update(gitdir, cfile, filename):
	"""
	Updates the file to its new version.
	"""
	#git-add doesn't accept absolute paths. 
	if isabs(filename):
		filename = filename.lstrip('/')
		check_call (["git-add", filename], env = {"GIT_DIR":gitdir}, cwd='/')
	else:
		check_call (["git-add", filename], env = {"GIT_DIR":gitdir})
	oldhead = _getTreeish(gitdir, 'refs/heads/master')
	_commit (gitdir, cfile, [oldhead])

def checkout(gitdir, ref, filename, codir):
	treeish = _getTreeish(gitdir, ref)
	check_call(["git-update-index", "--index-info"],env = {"GIT_DIR":gitdir}, 
			stdin = Popen(["git-ls-tree", "--full-name", "-r", treeish], 
				env = {"GIT_DIR":gitdir}, stdout=PIPE).stdout)
	gitdir = abspath(gitdir)
        check_call(["git-checkout-index", "-f", "--"] + [filename], env = {"GIT_DIR":gitdir}, cwd=codir)

def _makeRefname (id):
	return "refs/heads/" + id

def pull(base, repo, cfile, host, path, srcId):
	"""
	Pulls from a remote repository, 
	returns any new heads that have to be added to the conf file


	Base - the base wizbit directory
	repo - the git directory / repository
	"""
	gitdir = base + '/.wizbit/' + repo
	#Get all remote heads
	srcUrl = host + ':' + path
	remotes = Popen(["git-fetch-pack", "--all", srcUrl], env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0]
	remotes = [r.split() for r in remotes.split('\n') if r and r.split()[1] != 'HEAD']
	#Get all local heads
	repos = Conf.getRepos(cfile)
	heads = Conf.getHeads(cfile, repo)
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
			Conf.addHead(cfile, repo, refName)
	#Special case of an empty repository
	if not heads:
		for r in remotes:
			remoteref = r[1]
			remotesha = r[0]
                        check_call(["git-update-ref", remoteref, remotesha], env = {"GIT_DIR":gitdir})
			Conf.addHead(cfile, repo, remoteref)
	if checkoutFile:
		print 'HELP'
		print repo
		print base
		print gitdir
		checkout(gitdir, 'refs/heads/master', repo.rsplit('.git')[0], base) 

def log(gitdir):
	return Popen (["git-log", "--pretty=raw", "refs/heads/master"], env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0]

def commitInfo(gitdir, commit, filename):
	info = []
	results = Popen(["git-log", "-n1", "--pretty=format:%an%n%aD", commit],
			env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0]
	info.extend([item.strip() for item in results.split('\n')[:2]])
	results = Popen(["git-ls-tree", "-l", commit, filename],
			env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0]
	info.append(int(results.split()[3]))

	return tuple(info)
