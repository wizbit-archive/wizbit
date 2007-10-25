from util import getParams, getRepoName, getWizPath, makeRefname
from gitcommand import getOutput
import repo

def addEmpty(dir, file):
	"""
	Adds an empty git repository to the directory with a particular
	file name. This is needed for adding new files to a directory that
	are subsequently to be pushed to / pulled from a remote repository.
	"""
	dir, wizdir, wizconf = getParams(dir)
	repoName = getRepoName(file)
	try:
		os.mkdir(self.__wizdir + split(file)[0])
	except OSError:
		pass
	gitdir = abspath(self.__wizdir + repoName)
	repo.create(gitdir)
	conf.addRepo(wizconf, repoName)

def add(dir, file):
	"""
	Adds an existing file to the wizbit directory.
	"""
	dir, wizdir, wizconf = getParams(dir)
	repoName = getRepoName(file)
	addEmpty(file)
	ct = repo.add(repoName)

def mergeConfs(dir, new):
	"""
	Merges a wizbit.conf file. This means looking 
	for the files in the new conf that are not version controlled
	and initialising a repository for them and updating the current
	conf file with the new repositories. 
	Takes two XML strings. 
	"""
	dir, wizdir, wizconf = getParams(dir)
	cfile = open(self.__wizdir + '/wizbit.conf')
	current = cfile.read()
	cfile.close()
	curtree = etree.XML(current)
	newtree = etree.XML(new)
	#Get a list of all files in current and new
	currepos = [r.get("name") for r in curtree.xpath("/wizbit/repo")]
	newrepos = [r.get("name") for r in newtree.xpath("/wizbit/repo")]
	diff = [r for r in newrepos if r not in currepos]
	
	for file in diff:
		addEmpty(dir, file.rsplit('.git')[0])

def check_pull_needed (fromgitdir, remote_ref, togitdir):
    treeish = Popen (["git-ls-remote", "--heads", fromgitdir, remote_ref], stdout=PIPE).communicate()[0].split()[0]

    p = Popen(["git-rev-list", "--objects", treeish, "--not", "--all"], env = {"GIT_DIR":togitdir}, stdout=PIPE, stderr=PIPE)
    p.communicate();
    return p.returncode != 0

def make_refname (id):
    return "refs/heads/" + id


def remote_ref (repoel, id):
    toref = make_refname(id)
    els = repoel.xpath ("head[@ref='"+ toref +"']")
    if len(els) == 0:
        el = etree.SubElement(repoel, "head", ref = toref)
        etree.SubElement(el, "id").text = id
        return el
    else:
        return els[0]




def pull (fromdir, todir):
    fromwizdir = fromdir + "/.wizbit/"
    towizdir = todir + "/.wizbit/"
    fromwizbitconf = etree.parse (fromwizdir + "wizbit.conf")
    towizbitconf = etree.parse (towizdir + "wizbit.conf")
    fromid = fromwizbitconf.xpath("/wizbit/myid")[0].text
    for ef in fromwizbitconf.xpath("/wizbit/repo"):
        et = towizbitconf.xpath("/wizbit/repo[@name='"+ef.attrib["name"]+"']")[0]
        if et:
            fromgitdir = fromwizdir + ef.attrib["name"]
            togitdir = towizdir + ef.attrib["name"]
            pullneeded = False;
            for head in ef.findall("head"):
                print  check_pull_needed (fromgitdir, head.attrib["ref"], togitdir )

                pullneeded = pullneeded or check_pull_needed (fromgitdir, head.attrib["ref"], togitdir )
            if pullneeded:
                heads = Popen(["git-fetch-pack", "--all", fromgitdir], env = {"GIT_DIR":togitdir}, stdout=PIPE).communicate()[0]
                print heads
                for i in heads.split("\n")[:-1]:
                    ref = i.split()
                    print ref
                    if ref[1] == "refs/heads/master":
                        headish = get_treeish (togitdir, "refs/heads/master")
                        baseish = Popen(["git-merge-base", "--all", headish, ref[0]],env = {"GIT_DIR":togitdir}, stdout=PIPE).communicate()[0].strip()
                        if headish == baseish:
                            #head and merge base are teh same, so we can just
                            #fast-forward our master
                            print "fast forwarding master to ", ref[0]
                            print "headish",headish,"baseish",baseish
                            check_call(["git-update-ref","refs/heads/master", ref[0]], env = {"GIT_DIR":togitdir})
                        else:
                            el = remote_ref(et, fromid)
                            check_call(["git-update-ref",el.attrib["ref"], ref[0]], env = {"GIT_DIR":togitdir})
                    elif ref[1].startswith("refs/heads/"):
                        el = remote_ref(et, ref[0].split('/')[3])
                        check_call(["git-update-ref",el.attrib["ref"], ref[0]], env = {"GIT_DIR":togitdir})

    towizbitconf.write (towizdir + "wizbit.conf", pretty_print=True, encoding="utf-8", xml_declaration=True)

