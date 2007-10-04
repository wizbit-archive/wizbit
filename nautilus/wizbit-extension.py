from urlparse import urlparse
from os.path import exists, split, isdir

import nautilus
from lxml import etree

WIZ_CONTROLLED = "wiz-controlled"
WIZ_CONFLICT = "wiz-conflict"

YES = "Yes"
NO = "No"

class WizbitExtension(nautilus.ColumnProvider, nautilus.InfoProvider):
    def __init__(self):
        pass

    def get_columns(self):
        return [nautilus.Column("NautilusWizbit::is_controlled",
                                WIZ_CONTROLLED,
                                "Wizbit Controlled",
                                "File may be syncronized by Wizbit"),

                nautilus.Column("NautilusWizbit::has_conflict",
                                WIZ_CONFLICT,
                                "Wizbit Conflict",
                                "File may have multiple versions that need to be resolved")]

    def update_file_info(self, file):
        controlled = False
        conflict = False

        (scheme, netloc, path, params, query, fragment) = urlparse(file.get_uri())

        if scheme != 'file':
            return
        
        wizpath = self.get_wizpath(path)
        if wizpath:
            if isdir(path):
                controlled = True
            else:
                try:
                    repos = etree.parse (wizpath + "/.wizbit/repos")
                except IOError:
                    pass
                else:
                    #Find if file is controlled
                    files = [f.text for f in repos.getroot().xpath("/wizbit/repo/file")]
                    (path, filename) = split(path)
                    if filename in files:
                        controlled = True
                    
                        #Find if file is conflicting
                        repel = repos.getroot().xpath("/wizbit/repo")
                        for r in repel:
                            if r.get("name") == filename + ".git":
                                heads = [h for h in r if h.tag == "head"]
                                if len(heads) > 1:
                                    conflict = True

        if controlled:
            file.add_emblem("cvs-controlled")
            file.add_string_attribute(WIZ_CONTROLLED, YES)
        else:
            file.add_string_attribute(WIZ_CONTROLLED, NO)

        if conflict:
            file.add_emblem("cvs-conflict")
            file.add_string_attribute(WIZ_CONFLICT, YES)
        else:
            file.add_string_attribute(WIZ_CONFLICT, NO)

    def get_wizpath(self, path):
        if exists(path + "/.wizbit/repos"):
            return path
        else:
            (head, tail) = split(path)
            if head != '/':
                return self.get_wizpath(head)
            else:
                if exists("/.wizbit/repos"):
                    return head
                else:
                    return ""
