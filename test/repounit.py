import unittest

from os.path import exists, abspath
from os import remove, mkdir
from commands import getoutput

from wizbit import *
from wizbit import Conf, Repo

SHARE_ID = 'AShareId'
DIR_ID = 'ADirID'
MACHINE = 'AMachine'

TEST_FILE = 'atest'
BASE = abspath('.')

REMOTE_BASE = abspath('remote/')

TEST_STRING_ONE = 'This is a test string'
TEST_STRING_TWO = TEST_STRING_ONE + ' , something something.'
TEST_STRING_THREE = 'This is a third test string'

TEST_OUT_DIR = 'testout/'

REF = 'refs/heads/master'

class RepoCase(unittest.TestCase):
	def __createFile(self):
		wizpath = Paths(BASE)
		mkdir(wizpath.getWizdir())
		Conf.createConf(wizpath.getWizconf(), SHARE_ID, DIR_ID, MACHINE)
		file = open(TEST_FILE, 'w')
		file.write(TEST_STRING_ONE)
		file.close()
	
	def __clean(self):
		wizpath = Paths(BASE)
		getoutput('rm -rf %s' % wizpath.getWizdir())
		remove(TEST_FILE)

	def testCreate(self):
		self.__createFile()
		wizpath = Paths(BASE)
		Repo.create(wizpath, TEST_FILE)
		self.assertTrue(exists(wizpath.getRepoName(TEST_FILE)))
		self.__clean()

	def testAdd(self):
		self.__createFile()
		wizpath = Paths(BASE)
		Repo.create(wizpath, TEST_FILE)
		self.assertTrue(exists(wizpath.getRepoName(TEST_FILE)))
		Repo.add(wizpath, TEST_FILE)
		self.__clean()

	def testUpdate(self):
		self.__createFile()
		wizpath = Paths(BASE)
		Repo.create(wizpath, TEST_FILE)
		self.assertTrue(exists(wizpath.getRepoName(TEST_FILE)))
		Repo.add(wizpath, TEST_FILE)
		file = open(TEST_FILE, 'a')
		file.write(TEST_STRING_TWO)
		file.close()
		Repo.update(wizpath, TEST_FILE)
		self.__clean()

	def testCheckout(self):
		self.__createFile()
		wizpath = Paths(BASE)
		Repo.create(wizpath, TEST_FILE)
		self.assertTrue(exists(wizpath.getRepoName(TEST_FILE)))
		Repo.add(wizpath, TEST_FILE)
		getoutput('mkdir %s' % TEST_OUT_DIR)
		Repo.checkout(wizpath, TEST_FILE, REF, TEST_OUT_DIR)
		self.assertTrue(exists(TEST_OUT_DIR + TEST_FILE))
		remove(TEST_OUT_DIR + TEST_FILE)
		getoutput('rm -rf %s' % TEST_OUT_DIR)
		self.__clean()

	def testLog(self):
		self.__createFile()
		wizpath = Paths(BASE)
		Repo.create(wizpath, TEST_FILE)
		self.assertTrue(exists(wizpath.getRepoName(TEST_FILE)))
		Repo.add(wizpath, TEST_FILE)
		Repo.log(wizpath, TEST_FILE)
		self.__clean()

	def testCommitInfo(self):
		self.__createFile()
		wizpath = Paths(BASE)
		Repo.create(wizpath, TEST_FILE)
		self.assertTrue(exists(wizpath.getRepoName(TEST_FILE)))
		Repo.add(wizpath, TEST_FILE)
		Repo.commitInfo(wizpath, TEST_FILE, REF)
		self.__clean()

	def testPull(self):
		self.__createFile()
		wizpath = Paths(BASE)
		remotepath = Paths(REMOTE_BASE)
		Repo.create(wizpath, TEST_FILE)
		Repo.add(wizpath, TEST_FILE)
		mkdir(REMOTE_BASE)
		mkdir(remotepath.getWizdir())

		Conf.createConf(remotepath.getWizconf(), SHARE_ID, DIR_ID, MACHINE)
		Repo.create(remotepath, TEST_FILE)
		Conf.addRepo(remotepath.getWizconf(), TEST_FILE)
		srcId = Conf.getDirId(wizpath.getWizconf())
		host = 'localhost'
	
		Repo.pull(remotepath, TEST_FILE, host, BASE, srcId)

		file = open(TEST_FILE, 'a')
		file.write(TEST_STRING_TWO)
		file.close()
		Repo.update(wizpath, TEST_FILE)
		Repo.pull(remotepath, TEST_FILE, host, BASE, srcId)

		file = open(TEST_FILE, 'a')
		file.write(TEST_STRING_ONE)
		file.close()
		Repo.update(wizpath, TEST_FILE)
		file = open(remotepath.getAbsFilename(TEST_FILE), 'a')
		file.write(TEST_STRING_THREE)
		file.close()
		Repo.update(remotepath, TEST_FILE)
		Repo.pull(remotepath, TEST_FILE, host, BASE, srcId)
		getoutput('rm -rf %s' % REMOTE_BASE)
		self.__clean()

if __name__ == '__main__':
	unittest.main()
