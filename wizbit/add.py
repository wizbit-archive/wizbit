from subprocess import check_call, Popen, PIPE
from lxml import etree
from os.path import abspath, exists

def get_head (gitdir):
    return  Popen (["git-rev-list", "HEAD"], env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0].split()[0]


def commit (gitdir, parent):
    print "git dir:", gitdir
    tree = Popen (["git-write-tree"], env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0].split()[0]

    if parent:
        command = ["git-commit-tree",tree, "-p",parent]
    else:
        command = ["git-commit-tree",tree]

    commit = Popen (command, env = {"GIT_DIR":gitdir}, stdin = Popen(["echo"], stdout=PIPE).stdout, stdout = PIPE).communicate()[0].split()[0]
    # print "commit: ", commit

    check_call (["git-update-ref", "HEAD", commit], env = {"GIT_DIR":gitdir})
    return commit


def add (dir, file):
    wizdir = dir + "/.wizbit/"
    gitdir = wizdir + file + ".git"
    check_call (["git-init-db"], env = {"GIT_DIR":gitdir}, cwd=dir)
    check_call (["git-add", file], env = {"GIT_DIR":gitdir}, cwd=dir)
    ct = commit (gitdir, False)

    repos = etree.parse (wizdir + "repos")
    newrepo = etree.SubElement(repos.getroot(), "repo", attrib={"name":file+".git"})
    fileel = etree.SubElement(newrepo, "file")
    fileel.text = file
    head = etree.SubElement(newrepo, "head")
    head.text = ct

    repos.write (wizdir + "repos", pretty_print=True, encoding="utf-8", xml_declaration=True)

def update(dir, file):
    wizdir = dir + "/.wizbit/"
    gitdir = wizdir + file + ".git"
    check_call (["git-add", file], env = {"GIT_DIR":gitdir}, cwd=dir)
    oldhead = get_head(gitdir)
    ct = commit (gitdir, oldhead)
    repos = etree.parse (wizdir + "repos")
    for e in repos.xpath("/wizbit/repo/head"):
        if e.text == oldhead:
            e.text = ct
    repos.write (wizdir + "repos", pretty_print=True, encoding="utf-8", xml_declaration=True)

def pull (dir, file):
    wizdir = dir + "/.wizbit/"
    gitdir = wizdir + file + ".git"

def log (dir, repo):
    wizdir = dir + "/.wizbit/"
    gitdir = abspath(wizdir + repo)
    print gitdir
    log = Popen (["git-log", "--pretty=raw"], env = {"GIT_DIR":gitdir}, stdout=PIPE).communicate()[0]
    print log

def log_all (dir):
    wizdir = dir + "/.wizbit/"
    repos = etree.parse (wizdir + "repos")
    for e in repos.xpath("/wizbit/repo"):
        log (dir, e.attrib["name"])
    
