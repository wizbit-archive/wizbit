import os
import uuid
import platform
from commands import getoutput

from os.path import split, abspath, join

from wizbit import *
from wizbit import Conf, Repo, Shares

import socket
import xmlrpclib

from lxml import etree

# All variables named wizpath are the Path() object initilized to base directory. 
# Dirname implies a string that is the absolute path to the base directory.
# Filename implies relative from base directory.
# Absfilename is absolute name of file.

def _addEmpty(wizpath, filename):
    """
    Adds an empty git repository to the directory with a particular
    file name. This is needed for adding new files to a directory that
    are subsequently to be pushed to / pulled from a remote repository.
    """
    try:
        os.mkdir(split(wizpath.getAbsFilename(filename))[0])
    except OSError:
        pass
    return Repo.create(wizpath, filename)

def add(dirname, absfilename):
    """
    Adds an existing file to the wizbit directory.
    """
    wizpath = Paths(dirname)
    filename = wizpath.getRelFilename(absfilename)
    if _addEmpty(wizpath, filename):
        return Repo.add(wizpath, filename)
    else:
        return False

def pull(dirname, dirId, srchost):
    """
    Merges a wizbit.conf file. This means looking 
    for the files in the new conf that are not version controlled
    and initialising a repository for them and updating the current
    conf file with the new repositories. 
    Then pulling from the possibly remote repositories
    """
    wizpath = Paths(dirname)
    #Get the local conf
    cfile = open(wizpath.getWizconf())
    current = cfile.read()
    cfile.close()

    #Get the remote conf
    srcUrl = getWizUrl(srchost)
    server = xmlrpclib.ServerProxy(srcUrl)
    srcpath = server.getPath(dirId)
    new = server.getConf(dirId)

    curconf = etree.XML(current)
    newconf = etree.XML(new)

    #Get a list of all files in current and new
    currepos = [r.get("name") for r in curconf.xpath("/wizbit/repo")]
    newrepos = [r.get("name") for r in newconf.xpath("/wizbit/repo")]
    diff = [r for r in newrepos if r not in currepos]
    
    #Add empty repositories for any new files
    for filename in diff:
        _addEmpty(wizpath, filename)

    repos = Conf.getRepos(wizpath.getWizconf())
    for filename in repos:
        Repo.pull(wizpath, filename, srchost, srcpath, dirId)


def clone(dirname, dirId, srchost):
    """
    Clones a remote directory by 
    creating a new repository and updating
    from a possibly remote one.
    """
    srcUrl = getWizUrl(srchost)
    server = xmlrpclib.ServerProxy(srcUrl)
    srcConf = server.getConf(dirId)
    shareId = Conf.getRemoteShareId(srcConf)
    #Create the empty directory and update it
    cloneId = create(dirname, shareId)
    pull(dirname, dirId, srchost)
    return cloneId

def create (dirname, shareId=None):
    wizpath = Paths(dirname)
    os.makedirs (wizpath.getWizdir())
    shareId = shareId or uuid.uuid4().hex
    dirId = uuid.uuid4().hex
    Conf.createConf(wizpath.getWizconf(), shareId, dirId, platform.node())
    Shares.addShare(dirId, shareId, wizpath.getBase())
    return dirId

def createall(dirname):
    create(dirname)
    for root, dirs, files in os.walk(dirname):
        absfiles = [join(root, name) for name in files]
        for filename in absfiles:
            add(dirname, filename)
        if '.wizbit' in dirs:
            dirs.remove('.wizbit')

def remove(dirname):
    wizpath = Paths(dirname)
    dirId = Conf.getDirId(wizpath.getWizconf())
    Shares.removeShare(dirId)
    getoutput('rm -rf %s' % wizpath.getWizdir())
