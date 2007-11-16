import unittest

from os.path import exists, abspath
from os import remove, close
from commands import getoutput
from tempfile import mkstemp

import wizbit
from wizbit import Conf, Repo, Shares

SHRID = 'e3a361cc-1710-44d3-8582-ac7ff13fd7c0'
DIRID1 = '114a6a70-ff79-4cbb-8b91-6203eaef6afb'
DIRID2 = '94b47f79-53ed-4958-8a01-60bb65feac6d'
DIRID3 = 'f3e3e605-20ed-4200-b061-bfd75351e328'
DIRID4 = 'de92b93d-a274-456a-b484-efb0427beae7'

DIR1 = 'a/test/dir/one'
DIR2 = 'a/test/dir/two'
DIR3 = 'a/test/dir/three'
DIR4 = 'a/test/dir/four'

answer = [(DIRID1, SHRID, DIR1),
	  (DIRID2, SHRID, DIR2),
	  (DIRID3, SHRID, DIR3),
	  (DIRID4, SHRID, DIR4)]

class SharesCase(unittest.TestCase):
	def testAdd(self):
		handle, path = mkstemp ("wizbit-test")
		close(handle)
		s = Shares(path)
		s.addShare(DIRID1, SHRID, DIR1)
		s.addShare(DIRID2, SHRID, DIR2)
		s.addShare(DIRID3, SHRID, DIR3)
		s.addShare(DIRID4, SHRID, DIR4)
		result = s.getShares()
		self.assertEquals(result, answer)
		s.removeShare(DIRID1)
		s.removeShare(DIRID2)
		s.removeShare(DIRID3)
		s.removeShare(DIRID4)

if __name__ == '__main__':
	unittest.main()
