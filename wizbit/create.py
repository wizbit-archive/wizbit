import os
import wizbit

def _controlfile(base, dir, files):
    if ".wizbit" in files:
        files.remove(".wizbit")	    
    for f in files:
	if not os.path.isdir(dir + f):    
            wizbit.add(wizbit.getwizpath(dir), f)

def create (newdir):
    if not os.path.exists(newdir + "/.wizbit"):
        os.makedirs (newdir + "/.wizbit")
    os.path.walk(newdir, _controlfile, "/")
