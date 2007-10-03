#!/usr/bin/python
import sys
import os
from subprocess import Popen, check_call
from lxml import etree

def clone (olddir, newdir):
    print olddir, newdir
    oldwizdir = olddir + "/.wizbit/"
    newwizdir = newdir + "/.wizbit/"

    wizbit = etree.parse (oldwizdir + "repos")
    for i in wizbit.getiterator("repo"):
        print i.attrib

    try:
        os.makedirs (newwizdir)
    except:
        None

    for i in wizbit.getiterator("repo"):
        orig_git = oldwizdir + i.attrib["name"]
        dest_git = newwizdir +i.attrib["name"]
        check_call(["git","clone", "--bare",  orig_git , dest_git])
        check_call(["git","checkout"], env={"GIT_DIR":dest_git}, cwd=newdir)

    wizbit.write (newwizdir + "repos")
