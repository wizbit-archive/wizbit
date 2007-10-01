#!/usr/bin/python
import sys
import os
from subprocess import Popen
import xml.etree.ElementTree as et

def clone (olddir, newdir):
    oldwizdir = olddir + "/.wizbit/"
    newwizdir = newdir + "/.wizbit/"

    wizbit = et.parse (oldwizdir + "repos")
    for i in wizbit.getiterator("repo"):
        print i.attrib

    try:
        os.makedirs (newwizdir)
    except:
        None

    for i in wizbit.getiterator("repo"):
        orig_git = oldwizdir + i.attrib["name"]
        dest_git = newwizdir +i.attrib["name"]
        p = Popen(["git","clone", "--bare",  orig_git , dest_git])
        sts = os.waitpid (p.pid, 0)
        #TODO, check sucess
        p = Popen(["git","checkout"], env={"GIT_DIR":dest_git}, cwd=newdir)
        sts = os.waitpid (p.pid, 0)

