import dbus
import gobject
import avahi
import threading
import sys
from dbus.mainloop.glib import DBusGMainLoop

DBusGMainLoop( set_as_default=True )

"""
Class for publishing a service on DNS-SD using Avahi.
"""
class ServicePublisher (gobject.GObject):
    __gsignals__ = {
            'error': (gobject.SIGNAL_RUN_FIRST, gobject.TYPE_NONE,(gobject.TYPE_STRING,))
    }
    def __init__(self, name, type, port, txt = "", domain = "", host = ""):
        self.__gobject_init__()
        self._name = name
        self._type = type
        self._port = port
        self._txt = txt
        self._domain = ""
        self._host = ""
        self._group = None
        self._rename_count = 12 # Counter so we only rename after collisions a sensible number of times

        self._bus = dbus.SystemBus()

        self._server = dbus.Interface(
                self._bus.get_object( avahi.DBUS_NAME, avahi.DBUS_PATH_SERVER ),
                avahi.DBUS_INTERFACE_SERVER )

        self._server.connect_to_signal( 'StateChanged', self._server_state_changed )
        print "calling GetState"
        self._server_state_changed( self._server.GetState() )

    def __del__(self):
        if not self._group is None:
            self._group.Free()

    def _add_service(self):
        if self._group is None:
            self._group = dbus.Interface(
                    self._bus.get_object( avahi.DBUS_NAME, self._server.EntryGroupNew()),
                    avahi.DBUS_INTERFACE_ENTRY_GROUP)
            self._group.connect_to_signal('StateChanged', self._entry_group_state_changed)

        print "Adding service '%s' of type '%s' ..." % (self._name, self._type)

        while self._rename_count > 0:
            try:
                self._group.AddService(
                        avahi.IF_UNSPEC,    #interface
                        avahi.PROTO_UNSPEC, #protocol
                        0,                  #flags
                        self._name, self._type,
                        self._domain, self._host,
                        dbus.UInt16(self._port),
                        avahi.string_array_to_txt_array(self._txt))
                self._group.Commit()
                break
            except dbus.exceptions.DBusException, e:
                if e.get_dbus_name() == "org.freedesktop.Avahi.CollisionError":
                    self._name = self._server.GetAlternativeServiceName(self._name)
                    print "WARNING: Service name collision, changing name to '%s' ..." % self._name
                else:
                    throw(e)
                    break

    def _remove_service(self):
        if not self._group is None:
            self._group.Reset()

    def _server_state_changed(self, state):
        if state == avahi.SERVER_COLLISION:
            print "WARNING: Server name collision"
            self._remove_service()
        elif state == avahi.SERVER_RUNNING:
            self._add_service()

    def _entry_group_state_changed(self, state, error):
        print "state change: %i" % state

        if state == avahi.ENTRY_GROUP_ESTABLISHED:
            print "Service established."
        elif state == avahi.ENTRY_GROUP_COLLISION:
            self._rename_count = self._rename_count - 1
            if self._rename_count > 0:
                self._name = name = self._server.GetAlternativeServiceName(self._name)
                print "WARNING: Service name collision, changing name to '%s' ..." % self._name
                self._remove_service()
                self._add_service()

            else:
                print "ERROR: No suitable service name found after %i retries" % n_rename
                self.emit("error", "Service name collision failure")
                self._remove_service()
        elif state == avahi.ENTRY_GROUP_FAILURE:
            print "Error in group state changed", error
            return

class ServiceBrowser(gobject.GObject):
    __gsignals__ = {
            'service-found': (gobject.SIGNAL_RUN_FIRST, gobject.TYPE_NONE,(gobject.TYPE_STRING, gobject.TYPE_STRING, gobject.TYPE_INT, gobject.TYPE_STRING, gobject.TYPE_STRING, gobject.TYPE_INT)),
            'service-removed': (gobject.SIGNAL_RUN_FIRST, gobject.TYPE_NONE,(gobject.TYPE_STRING, ))
    }

    def __init__(self, type, domain = ""):
        self.__gobject_init__()
        bus = dbus.SystemBus()
        self._server = dbus.Interface(bus.get_object(avahi.DBUS_NAME, avahi.DBUS_PATH_SERVER), avahi.DBUS_INTERFACE_SERVER)
        print "creating service browser for ",type
        self._browser = dbus.Interface(bus.get_object(avahi.DBUS_NAME, self._server.ServiceBrowserNew(avahi.IF_UNSPEC, avahi.PROTO_INET, type, domain, dbus.UInt32(0))), avahi.DBUS_INTERFACE_SERVICE_BROWSER)
        self._browser.connect_to_signal('ItemNew', self._new_service)
        self._browser.connect_to_signal('ItemRemove', self._remove_service)
        self.services = {}

    def _service_resolved (self, interface, protocol, name, type, domain, host, aprotocol, address, port, txt, flags):
        print "Service data for service '%s' of type '%s' in domain '%s' on %s.%i:" % (name, type, domain, self._siocgifname(interface), protocol)
        print "\tHost %s (%s), port %i, TXT data: %s" % (host, address, port, avahi.txt_array_to_string_array(txt))
        self.services[name] = (type, interface, host, address, port)
        self.emit('service-found', name, type, interface, host, address, port)

    def _new_service(self, interface, protocol, name, type, domain, flags):
        print "new service:",interface, protocol, name, type, domain, flags
        self._server.ResolveService(interface, protocol, name, type, domain, avahi.PROTO_INET, dbus.UInt32(0), reply_handler=self._service_resolved, error_handler=self._print_error)


    def _remove_service(self, interface, protocol, name, type, domain, flags):
        print "remove service:", interface, protocol, name, type, domain, flags
        self.emit('service-removed', name)
        del self.services[name]

    def _print_error(self, error):
        print error
    def _siocgifname(self, interface):
        if interface <= 0:
            return "any"
        else:
            return self._server.GetNetworkInterfaceNameByIndex(interface)


class SharesDatabase(gobject.GObject):
    def __init__(self):
        self.sb =ServiceBrowser("_wizbit._tcp")
        self.sb.connect ( "service-found", self._service_found)
        self.sb.connect ( "service-removed", self._service_removed)

        self.shares = {}
        self.names = {}

    def _service_found(self, widget, name, type, interface, host, address, port):
        print (name, type, interface, host, address, port);

        srcUrl = getWizUrl(address, port)
        server = xmlrpclib.ServerProxy(srcUrl)
        shares = server.getShares()
        print shares
        for dirId, shareId, dir in shares:
            if shareId not in self.shares:
                self.shares[shareId] = {}
            self.shares[shareId][dirId] = (interface, address, port, dir)
            if name not in self.names:
                self.names[name] = []
            self.names[name].append((shrId,dirId))

    def _service_removed(self, widget, name):
        for shrId, dirId in self.names[name]:
            del self.shares[shrId][dirId]
            if self.shares[shrId] == {}:
                    del self.shares[shrId]

if __name__ == "__main__":
    if len(sys.argv) > 1:
        name = sys.argv[1]
    else:
        name = "test"

    sp = ServicePublisher(name,"_test._tcp",1234)
    sb = ServiceBrowser("_test._tcp")

    mainloop = gobject.MainLoop()
    try:
        mainloop.run()
    except KeyboardInterrupt:
        pass
