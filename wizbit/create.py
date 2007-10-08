import os
import uuid
import platform
from lxml import etree

def create (newdir):
    wizdir = newdir + "/.wizbit/"
    os.makedirs (wizdir)
    root = etree.Element("wizbit")
    wizbitconf = etree.ElementTree(root)
    id = etree.SubElement (root, "myid")
    id.text = uuid.uuid4().hex
    machine = etree.SubElement (root, "machine")
    machine.text = platform.node()
    wizbitconf.write (wizdir + "wizbit.conf", pretty_print=True, encoding="utf-8", xml_declaration=True)
    return id.text
