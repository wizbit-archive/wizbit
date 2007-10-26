import unittest

from os.path import exists
from os import remove

import wizbit
from wizbit import Conf, Repo

CONF_FILE = 'testconf.xml'
SHARE_ID = 'AShareId'
DIR_ID = 'ADirID'
MACHINE = 'AMachine'

GIT_DIR = 'atest.git'
TEST_FILE = 'atest'
TEST_STRING_ONE = 'This is a test string'
TEST_STRING_TWO = TEST_STRING_ONE + ' , something something.'

TEST_OUT_DIR = 'testout/'
REF = 'refs/heads/master'

class RepoCase(unittest.TestCase):
	def __createFile(self):
		Conf.createConf(CONF_FILE, SHARE_ID, DIR_ID, MACHINE)
		file = open(TEST_FILE, 'w')
		file.write(TEST_STRING_ONE)
		file.close()
	
	def __clean(self):
		getoutput('rm -rf %s' % GIT_DIR)
		remove(TEST_FILE)
		remove(CONF_FILE)

	def testCreate(self):
		self.__createFile()
		Repo.create(GIT_DIR)
		self.assertTrue(exists(GIT_DIR))
		self.__clean()

	def testAdd(self):
		self.__createFile()
		Repo.create(GIT_DIR)
		self.assertTrue(exists(TEST_FILE))
		Repo.add(GIT_DIR, CONF_FILE)	
		self.__clean()

	def testUpdate(self):
		self.__createFile()
		Repo.create(GIT_DIR)
		self.assertTrue(exists(TEST_FILE))
		Repo.add(GIT_DIR, CONF_FILE)	
		file = open(TEST_FILE, 'a')
		file = open(TEST_FILE, 'a')
		file.write(TEST_STRING_TWO)
		file.close()
		Repo.update(GIT_DIR, CONF_FILE)
		self.__clean()

	def testCheckout(self):
		self.__createFile()
		Repo.create(GIT_DIR)
		self.assertTrue(exists(TEST_FILE))
		Repo.add(GIT_DIR, CONF_FILE)	
		getoutput('mkdir %s' % TEST_OUT_DIR)
		Repo.checkout(GIT_DIR, REF, TEST_OUT_DIR)
		self.assertTrue(exists(TEST_OUT_DIR + TEST_FILE))
		remove(TEST_OUT_DIR + TEST_FILE)
		getoutput('rm -rf %s' % TEST_OUT_DIR)
		self.__clean()

	def testLog(self):
		self.__createFile()
		Repo.create(GIT_DIR)
		self.assertTrue(exists(TEST_FILE))
		Repo.add(GIT_DIR, CONF_FILE)	
		Repo.log(GIT_DIR)
		self.__clean()

	def testCommitInfo(self):
		self.__createFile()
		Repo.create(GIT_DIR)
		self.assertTrue(exists(TEST_FILE))
		Repo.add(GIT_DIR, CONF_FILE)	
		Repo.commitInfo(GIT_DIR, REF)
		self.__clean()

if __name__ == '__main__':
	unittest.main()
