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

TEST_DIR = abspath('ATestDir')
CLONE_DIR = abspath('ACloneDir')
TEST_FILE = TEST_DIR + '/atest'
TEST_STRING_ONE = 'This is a test string'
SOURCE_HOST = 'localhost'

class DirectoryCase(unittest.TestCase):
	def __startDaemon(self):
		#self.__daemon = subprocess.Popen(['python', '../wizd/wizd.py'])
		pass

	def __killDaemon(self):
		#os.kill(self.__daemon.pid, signal.SIGKILL)
		pass

	def __createFile(self):
		file = open(TEST_FILE, 'w')
		file.write(TEST_STRING_ONE)
		file.close()

	def __clean(self):
		getoutput('rm -rf %s' % TEST_DIR)

	def testDaemon(self):
		try:
			self.__startDaemon()
			srcUrl = getWizUrl(SOURCE_HOST)
			server = xmlrpclib.ServerProxy(srcUrl)
			methods = server.system.listMethods()
			print methods
		finally:
			self.__killDaemon()

	def testCreate(self):
		dirId = ""
		try:
			self.__startDaemon()
			dirId = Directory.create(TEST_DIR)
			result = Shares.getShares()
			self.assertEquals([(dirId, TEST_DIR)], result)
			srcUrl = getWizUrl(SOURCE_HOST)
			server = xmlrpclib.ServerProxy(srcUrl)
			newconf = server.getConf(dirId)
			print newconf
		finally:
			Shares.removeShare(dirId)
			self.__clean()
			self.__killDaemon()

	def testAdd(self):
		dirId = ""
		try:
			self.__startDaemon()
			dirId = Directory.create(TEST_DIR)
			self.__createFile()
			result = Shares.getShares()
			self.assertEquals([(dirId, TEST_DIR)], result)
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
			self.__killDaemon()

	def testClone(self):
		dirId = ""
		cloneId = ""
		try:
			self.__startDaemon()
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
			getoutput('rm -rf %s' % CLONE_DIR)
			self.__clean()
			self.__killDaemon()

if __name__ == '__main__':
	unittest.main()
