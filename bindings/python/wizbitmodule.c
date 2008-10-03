#include <pygobject.h>

void wizbit_register_classes (PyObject *d);
extern PyMethodDef wizbit_functions[];

DL_EXPORT(void)
init_wizbit(void)
{
	PyObject *m, *d;

	init_pygobject ();

	m = Py_InitModule ("_wizbit", wizbit_functions);
	d = PyModule_GetDict (m);

	wizbit_register_classes (d);

	if (PyErr_Occurred ()) {
		Py_FatalError ("can't initialise module wizbit");
	}
}

