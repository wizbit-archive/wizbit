import unittest

from os.path import exists, abspath
from os import remove
from commands import getoutput

import wizbit
from wizbit import Conf, Repo, Shares

UUID1 = 'sdvseoviwjeocijweomc'
UUID2 = 'segweawdq23e2aldasdk'
UUID3 = 'schyawdo9iwdjoaismca'
UUID4 = 'svsdIU3REFUSDsciuhdv'

DIR1 = 'a/test/dir/one'
DIR2 = 'a/test/dir/two'
DIR3 = 'a/test/dir/three'
DIR4 = 'a/test/dir/four'

answer = [(UUID1, DIR1),
		(UUID2, DIR2),
		(UUID3, DIR3),
		(UUID4, DIR4)]

class SharesCase(unittest.TestCase):
	def testAdd(self):
		Shares.addShare(UUID1, DIR1)
		Shares.addShare(UUID2, DIR2)
		Shares.addShare(UUID3, DIR3)
		Shares.addShare(UUID4, DIR4)
		result = Shares.getShares()
		self.assertEquals(result, answer)
		Shares.removeShare(UUID1)
		Shares.removeShare(UUID2)
		Shares.removeShare(UUID3)
		Shares.removeShare(UUID4)

if __name__ == '__main__':
	unittest.main()
