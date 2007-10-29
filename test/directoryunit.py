import unittest
import os
from os.path import abspath

from wizbit import *
from wizbit import Conf, Repo, Directory, Shares

import subprocess
import signal

from commands import getoutput

import socket
import xmlrpclib
import signal

TEST_DIR = 'ATestDir'
CLONE_DIR = 'ACloneDir'
TEST_FILE = TEST_DIR + '/atest'
TEST_STRING_ONE = 'This is a test string'
GIT_DIR = TEST_DIR + TEST_FILE + '.git'
SOURCE_HOST = 'localhost'

class DirectoryCase(unittest.TestCase):
	def __startDeamon(self):
		#self.__deamon = subprocess.Popen(['python', '../wizd/wizd.py'])
		pass

	def __killDeamon(self):
		#os.kill(self.__deamon.pid, signal.SIGKILL)
		pass

	def __createFile(self):
		file = open(TEST_FILE, 'w')
		file.write(TEST_STRING_ONE)
		file.close()

	def __clean(self):
		getoutput('rm -rf %s' % TEST_DIR)
	"""
	def testDeamon(self):
		try:
			self.__startDeamon()
			srcUrl = getWizUrl(SOURCE_HOST)
			server = xmlrpclib.ServerProxy(srcUrl)
			methods = server.system.listMethods()
			print methods
		finally:
			self.__killDeamon()

	def testCreate(self):
		dirId = ""
		try:
			self.__startDeamon()
			dirId = Directory.create(TEST_DIR)
			result = Shares.getShares()
			self.assertEquals([(dirId, abspath(TEST_DIR) + '/.wizbit/')], result)
			srcUrl = getWizUrl(SOURCE_HOST)
			server = xmlrpclib.ServerProxy(srcUrl)
			newconf = server.getConf(dirId)
			print newconf
		finally:
			Shares.removeShare(dirId)
			self.__clean()
			self.__killDeamon()

	def testAdd(self):
		dirId = ""
		try:
			self.__startDeamon()
			dirId = Directory.create(TEST_DIR)
			self.__createFile()
			result = Shares.getShares()
			self.assertEquals([(dirId, abspath(TEST_DIR) + '/.wizbit/')], result)
			srcUrl = getWizUrl(SOURCE_HOST)
			server = xmlrpclib.ServerProxy(srcUrl)
			newconf = server.getConf(dirId)
			print newconf
			Directory.add(TEST_DIR, TEST_FILE)
			newconf = server.getConf(dirId)
			print newconf
		finally:
			Shares.removeShare(dirId)
			self.__clean()
			self.__killDeamon()
	"""

	def testClone(self):
		dirId = ""
		cloneId = ""
		try:
			self.__startDeamon()
			dirId = Directory.create(TEST_DIR)
			self.__createFile()
			result = Shares.getShares()
			srcUrl = getWizUrl(SOURCE_HOST)
			server = xmlrpclib.ServerProxy(srcUrl)
			Directory.add(TEST_DIR, TEST_FILE)
			cloneId = Directory.clone(CLONE_DIR, dirId, SOURCE_HOST)
		finally:
			Shares.removeShare(dirId)
			Shares.removeShare(cloneId)
			self.__clean()
			self.__killDeamon()

if __name__ == '__main__':
	unittest.main()
