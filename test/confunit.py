import unittest
from wizbit import Conf

from os.path import exists
from os import remove

CONF_FILE = 'testconf.xml'
SHARE_ID = 'AShareId'
DIR_ID = 'ADirID'
MACHINE = 'AMachine'

class ConfCase(unittest.TestCase):
    def testCreate(self):
        Conf.createConf(CONF_FILE, SHARE_ID, DIR_ID, MACHINE)
        self.assertTrue(exists(CONF_FILE))
        self.assertEqual(Conf.getShareId(CONF_FILE), SHARE_ID)
        self.assertEqual(Conf.getDirId(CONF_FILE), DIR_ID)
        remove(CONF_FILE)

    def testRepo(self):
        R1 = 'RepositoryOne'
        R2 = 'RepositoryTwo'
        R3 = 'RepositoryThree'
        R4 = 'RepositoryFour'
        H1 = 'HeadRefOne'
        Conf.createConf(CONF_FILE, SHARE_ID, DIR_ID, MACHINE)
        self.assertTrue(exists(CONF_FILE))
        Conf.addRepo(CONF_FILE, R1)
        Conf.addRepo(CONF_FILE, R2)
        Conf.addRepo(CONF_FILE, R3)
        testRepos = [R1, R2, R3]
        repos = Conf.getRepos(CONF_FILE)
        self.assertEqual(repos, testRepos)
        testHeads = [H1]
        Conf.addRepo(CONF_FILE, R4, H1)
        heads = Conf.getHeads(CONF_FILE, R4)
        self.assertEqual(heads, testHeads)
        remove(CONF_FILE)

    def testHeads(self):
        R1 = 'RepositoryOne'
        H1 = 'HeadRefOne'
        H2 = 'HeadRefTwo'
        H3 = 'HeadRefThree'
        M1 = 'HeadRefTwo'
        Conf.createConf(CONF_FILE, SHARE_ID, DIR_ID, MACHINE)
        self.assertTrue(exists(CONF_FILE))
        Conf.addRepo(CONF_FILE, R1)
        Conf.addHead(CONF_FILE, R1, H1)
        Conf.addHead(CONF_FILE, R1, H2)
        Conf.addHead(CONF_FILE, R1, H3)
        testHeads = [H1, H2, H3]
        heads = Conf.getHeads(CONF_FILE, R1)
        self.assertEqual(heads, testHeads)
        Conf.removeHead(CONF_FILE, R1, H1)
        testHeads = [H2, H3]
        heads = Conf.getHeads(CONF_FILE, R1)
        self.assertEqual(heads, testHeads)
        Conf.removeHead(CONF_FILE, R1, H3)
        testHeads = [H2]
        heads = Conf.getHeads(CONF_FILE, R1)
        self.assertEqual(heads, testHeads)
        Conf.removeHead(CONF_FILE, R1, H3)
        testHeads = [H2]
        heads = Conf.getHeads(CONF_FILE, R1)
        self.assertEqual(heads, testHeads)
        remove(CONF_FILE)

if __name__ == '__main__':
    unittest.main()
