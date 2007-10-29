import unittest

from os.path import exists, abspath
from os import remove
from commands import getoutput

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
TEST_STRING_THREE = 'This is a third test string'

TEST_OUT_DIR = 'testout/'
REF = 'refs/heads/master'

REMOTE_CONF_FILE = TEST_OUT_DIR + CONF_FILE
REMOTE_GIT_DIR = TEST_OUT_DIR + GIT_DIR
REMOTE_DIR_ID = 'ARemoteDirID'
REMOTE_TEST_FILE = TEST_OUT_DIR + TEST_FILE

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
		Repo.create(GIT_DIR, CONF_FILE, TEST_FILE)
		self.assertTrue(exists(GIT_DIR))
		self.__clean()

	def testAdd(self):
		self.__createFile()
		Repo.create(GIT_DIR, CONF_FILE, TEST_FILE)
		self.assertTrue(exists(TEST_FILE))
		Repo.add(abspath(GIT_DIR), CONF_FILE, '.', TEST_FILE)	
		self.__clean()

	def testUpdate(self):
		self.__createFile()
		Repo.create(GIT_DIR, CONF_FILE, TEST_FILE)
		self.assertTrue(exists(TEST_FILE))
		Repo.add(GIT_DIR, CONF_FILE, '.', TEST_FILE)	
		file = open(TEST_FILE, 'a')
		file.write(TEST_STRING_TWO)
		file.close()
		Repo.update(GIT_DIR, CONF_FILE, TEST_FILE)
		self.__clean()

	def testCheckout(self):
		self.__createFile()
		Repo.create(GIT_DIR, CONF_FILE, TEST_FILE)
		self.assertTrue(exists(TEST_FILE))
		Repo.add(GIT_DIR, CONF_FILE, '.', TEST_FILE)	
		getoutput('mkdir %s' % TEST_OUT_DIR)
		Repo.checkout(GIT_DIR, REF, TEST_FILE, TEST_OUT_DIR)
		self.assertTrue(exists(TEST_OUT_DIR + TEST_FILE))
		remove(TEST_OUT_DIR + TEST_FILE)
		getoutput('rm -rf %s' % TEST_OUT_DIR)
		self.__clean()

	def testLog(self):
		self.__createFile()
		Repo.create(GIT_DIR, CONF_FILE, TEST_FILE)
		self.assertTrue(exists(TEST_FILE))
		Repo.add(GIT_DIR, CONF_FILE, '.', TEST_FILE)	
		Repo.log(GIT_DIR)
		self.__clean()

	def testCommitInfo(self):
		self.__createFile()
		Repo.create(GIT_DIR, CONF_FILE, TEST_FILE)
		self.assertTrue(exists(TEST_FILE))
		Repo.add(GIT_DIR, CONF_FILE, '.', TEST_FILE)	
		Repo.commitInfo(GIT_DIR, REF, TEST_FILE)
		self.__clean()

	def testPull(self):
		self.__createFile()
		Repo.create(GIT_DIR, CONF_FILE, TEST_FILE)
		Repo.add(GIT_DIR, CONF_FILE, '.', TEST_FILE)	
		getoutput('mkdir %s' % TEST_OUT_DIR)
		Conf.createConf(REMOTE_CONF_FILE, SHARE_ID, REMOTE_DIR_ID, MACHINE)
		Repo.create(REMOTE_GIT_DIR, REMOTE_CONF_FILE, TEST_FILE)
		Conf.addRepo(REMOTE_CONF_FILE, REMOTE_GIT_DIR)
		srcId = Conf.getDirId(CONF_FILE)
		host = 'localhost'
		path = abspath(GIT_DIR)
		Repo.pull('./', REMOTE_GIT_DIR, REMOTE_CONF_FILE, host, path, srcId)
		Repo.checkout(REMOTE_GIT_DIR, REF, TEST_FILE, TEST_OUT_DIR) 
		file = open(TEST_FILE, 'a')
		file.write(TEST_STRING_TWO)
		file.close()
		Repo.update(GIT_DIR, CONF_FILE, TEST_FILE)
		Repo.pull('./', REMOTE_GIT_DIR, REMOTE_CONF_FILE, host, path, srcId)
		Repo.checkout(REMOTE_GIT_DIR, REF, TEST_FILE, TEST_OUT_DIR) 
		file = open(TEST_FILE, 'a')
		file.write(TEST_STRING_ONE)
		file.close()
		Repo.update(GIT_DIR, CONF_FILE, TEST_FILE)
		file = open(REMOTE_TEST_FILE, 'a')
		file.write(TEST_STRING_THREE)
		file.close()
		Repo.update(REMOTE_GIT_DIR, REMOTE_CONF_FILE, TEST_FILE)
		Repo.pull('./', REMOTE_GIT_DIR, REMOTE_CONF_FILE, host, path, srcId)
		Repo.checkout(REMOTE_GIT_DIR, REF, TEST_FILE, TEST_OUT_DIR) 
		getoutput('rm -rf %s' % TEST_OUT_DIR)
		self.__clean()

if __name__ == '__main__':
	unittest.main()
