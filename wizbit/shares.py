import os
from fcntl import flock, LOCK_EX 

WIZSHARE_DATA_PATH = os.environ["HOME"] + "/.wizdirs"

def _waitOnFlock(file):
	# Wait forever to obtain the file lock
	obtained = False
	while (not obtained):
		try:
			flock(file, LOCK_EX)
			obtained = True
		except IOError:
			pass

def addShare(uuid, dir):
	file = open(WIZSHARE_DATA_PATH, "a")
	_waitOnFlock(file)
	file.write("%s %s\n" % (uuid, dir))
	file.close()

def removeShare(uuid):
	file = open(WIZSHARE_DATA_PATH, "r+")
	_waitOnFlock(file)
	input = file.readlines()
	file.seek(0)
	for line in input:
		(lineid, dir) = line.split()[0:2]
		if lineid != uuid:
			file.write(line)
	file.truncate()
	file.close()

def create (newdir):
   	wizdir = newdir + "/.wizbit/"
   	os.makedirs (wizdir)
   	root = etree.Element("wizbit")
   	wizbitconf = etree.ElementTree(root)
   	id = etree.SubElement (root, "myid")
   	id.text = uuid.uuid4().hex
   	machine = etree.SubElement (root, "machine")
   	machine.text = platform.node()
   	wizbitconf.write (wizdir + "wizbit.conf", pretty_print=True, encoding="utf-8", xml_declaration=True)
	shares.addShare(id.text, wizdir)
	return id.text

def clone (olddir, newdir):
    print olddir, newdir

    myid = create (newdir)

    oldwizdir = olddir + "/.wizbit/"
    newwizdir = newdir + "/.wizbit/"

    wizbitconf = etree.parse (oldwizdir + "wizbit.conf")
    new_wizbitconf = etree.parse (newwizdir + "wizbit.conf")
    for i in wizbitconf.getiterator("repo"):
        print i.attrib

    for i in wizbitconf.getiterator("repo"):
        name = i.attrib["name"]
        orig_git = oldwizdir + name
        dest_git = newwizdir + name
        repo = etree.SubElement(new_wizbitconf.getroot(), "repo", name=name)
        check_call(["git","clone", "--bare",  orig_git , dest_git])
        checkout (newdir, [], "master", gitdir=dest_git)

        for j in i.getiterator("head"):
            if j.attrib["ref"] == "refs/heads/master":
                head = etree.SubElement(repo, "head", ref="refs/heads/master")
                etree.SubElement(head, "id").text = myid
            else:
                head = etree.SubElement(repo, "head", ref=j.attrib["ref"])
                etree.SubElement(head, "id").text = j.find("id").text

    new_wizbitconf.write (newwizdir + "wizbit.conf", pretty_print=True, encoding="utf-8", xml_declaration=True)
