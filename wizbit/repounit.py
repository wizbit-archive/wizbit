import unittest
import repo

from os.path import exists
from os import remove
from commands import getoutput
from util import getFileName 

GIT_DIR = 'atest.git'
TEST_FILE = 'atest'
TEST_STRING_ONE = 'This is a test string'
TEST_STRING_TWO = TEST_STRING_ONE + ' , something something.'

TEST_OUT_DIR = 'testout/'
REF = 'refs/heads/master'

class RepoCase(unittest.TestCase):
	def __createFile(self):
		file = open(TEST_FILE, 'w')
		file.write(TEST_STRING_ONE)
		file.close()
	
	def __clean(self):
		getoutput('rm -rf %s' % GIT_DIR)
		remove(TEST_FILE)

	def testCreate(self):
		self.__createFile()
		repo.create(GIT_DIR)
		self.assertTrue(exists(GIT_DIR))
		self.__clean()

	def testAdd(self):
		self.__createFile()
		repo.create(GIT_DIR)
		self.assertTrue(exists(TEST_FILE))
		repo.add(GIT_DIR)	
		self.__clean()

	def testUpdate(self):
		self.__createFile()
		repo.create(GIT_DIR)
		self.assertTrue(exists(TEST_FILE))
		repo.add(GIT_DIR)	
		file = open(TEST_FILE, 'a')
		file.write(TEST_STRING_TWO)
		file.close()
		repo.update(GIT_DIR)
		self.__clean()

	def testCheckout(self):
		self.__createFile()
		repo.create(GIT_DIR)
		self.assertTrue(exists(TEST_FILE))
		repo.add(GIT_DIR)	
		getoutput('mkdir %s' % TEST_OUT_DIR)
		repo.checkout(GIT_DIR, REF, TEST_OUT_DIR)
		self.assertTrue(exists(TEST_OUT_DIR + TEST_FILE))
		remove(TEST_OUT_DIR + TEST_FILE)
		getoutput('rm -rf %s' % TEST_OUT_DIR)
		self.__clean()

	def testLog(self):
		self.__createFile()
		repo.create(GIT_DIR)
		self.assertTrue(exists(TEST_FILE))
		repo.add(GIT_DIR)	
		repo.log(GIT_DIR)
		self.__clean()

	def testCommitInfo(self):
		self.__createFile()
		repo.create(GIT_DIR)
		self.assertTrue(exists(TEST_FILE))
		repo.add(GIT_DIR)	
		repo.commitInfo(GIT_DIR, REF)
		self.__clean()

if __name__ == '__main__':
	unittest.main()
