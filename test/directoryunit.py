import unittest
import os

import wizbit
from wizbit import Conf, Repo, Directory

import subprocess
import signal

class DirectoryCase(unittest.TestCase):
	def __startDeamon(self):
		self.__deamon = subprocess.Popen(['python', '../wizd/wizd.py'])

	def __killDeamon(self):
		os.kill(self.__deamon.pid, signal.SIGKILL)
