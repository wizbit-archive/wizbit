#!/usr/bin/python
import sys
import os
from create import *
from add import *
from subprocess import Popen, check_call
from lxml import etree

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
