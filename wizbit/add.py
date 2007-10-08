from subprocess import call, check_call, Popen, PIPE
from lxml import etree
from os.path import abspath, exists

def get_treeish(gitdir,ref):
    return Popen (["git-show-ref", ref], env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0].split()[0]

def commit (gitdir, parents):
    print "git dir:", gitdir
    tree = Popen (["git-write-tree"], env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0].split()[0]

    command = ["git-commit-tree",tree]
    for parent in parents:
        command = command + ["-p",parent]

    commit = Popen (command, env = {"GIT_DIR":gitdir}, stdin = Popen(["echo"], stdout=PIPE).stdout, stdout = PIPE).communicate()[0].split()[0]
    # print "commit: ", commit

    check_call (["git-update-ref", "refs/heads/master", commit], env = {"GIT_DIR":gitdir})
    return commit

def merge_commit (dir, file, refs):
    wizdir = dir + "/.wizbit/"
    gitdir = abspath(wizdir + file + ".git")

    check_call (["git-add", "-u"], env = {"GIT_DIR":gitdir}, cwd=dir)

    heads = [get_treeish(gitdir,"refs/heads/" + i) for i in refs]

    ct = commit(gitdir, heads);
    wizbitconf = etree.parse (wizdir + "wizbit.conf")
    xpath = "/wizbit/repo[@name='"+file+".git']/head"
    for e in wizbitconf.xpath(xpath):
        if e.text in heads:
            e.text = ct
    wizbitconf.write (wizdir + "wizbit.conf", pretty_print=True, encoding="utf-8", xml_declaration=True)


def add (dir, file):
    wizdir = dir + "/.wizbit/"
    gitdir = abspath(wizdir + file + ".git")
    check_call (["git-init-db"], env = {"GIT_DIR":gitdir}, cwd=dir)
    check_call (["git-add", file], env = {"GIT_DIR":gitdir}, cwd=dir)
    ct = commit (gitdir, [])

    wizbitconf = etree.parse (wizdir + "wizbit.conf")

    myid = wizbitconf.find("myid").text

    newrepo = etree.SubElement(wizbitconf.getroot(), "repo", attrib={"name":file+".git"})
    fileel = etree.SubElement(newrepo, "file")
    fileel.text = file
    head = etree.SubElement(newrepo, "head", ref="refs/heads/master")
    etree.SubElement(head, "id").text = myid

    wizbitconf.write (wizdir + "wizbit.conf", pretty_print=True, encoding="utf-8", xml_declaration=True)

def update(dir, file):
    wizdir = dir + "/.wizbit/"
    gitdir = abspath(wizdir + file + ".git")
    check_call (["git-add", file], env = {"GIT_DIR":gitdir}, cwd=dir)
    oldhead = get_treeish(gitdir, "refs/heads/master")
    ct = commit (gitdir, [oldhead])
    wizbitconf = etree.parse (wizdir + "wizbit.conf")
    xpath = "/wizbit/repo[@name='"+file+".git']/head"
    for e in wizbitconf.xpath(xpath):
        if e.text == oldhead:
            e.text = ct
    wizbitconf.write (wizdir + "wizbit.conf", pretty_print=True, encoding="utf-8", xml_declaration=True)


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
                        headish= Popen (["git-show-ref", "refs/heads/master"], env = {"GIT_DIR":togitdir}, stdout=PIPE).communicate()[0].split()[0]
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




def log (dir, repo):
    wizdir = dir + "/.wizbit/"
    gitdir = abspath(wizdir + repo)
    print gitdir
    log = Popen (["git-log", "--pretty=raw", "refs/heads/master"], env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0]
    print log

def log_all (dir):
    wizdir = dir + "/.wizbit/"
    wizbitconf = etree.parse (wizdir + "wizbit.conf")
    for e in wizbitconf.xpath("/wizbit/repo"):
        log (dir, e.attrib["name"])

def checkout (dir, files, ref, **kwargs):
    wizdir = dir + "/.wizbit/"
    gitdir = kwargs["gitdir"] or abspath(wizdir + file + ".git")

    treeish = Popen (["git-show-ref", ref], env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0].split()[0]
    print "treeish:", treeish
    check_call(["git-update-index", "--index-info"],env = {"GIT_DIR":gitdir},
            stdin = Popen(["git-ls-tree", "--full-name", "-r", treeish], 
                env = {"GIT_DIR":gitdir}, stdout=PIPE).stdout)

    if len(files) > 0:
        check_call(["git-checkout-index", "-f", "--"] + files, env = {"GIT_DIR":gitdir}, cwd=dir)
    else:
        print "checking out all"
        check_call(["git-checkout-index", "-f", "-a"], env = {"GIT_DIR":gitdir}, cwd=dir)

