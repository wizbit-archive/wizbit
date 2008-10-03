include $(top_srcdir)/Makefile.decl

AssemblyInfo.cs:
	cp $(srcdir)/AssemblyInfo.cs.in $@
wizbit-sharp.snk:
	cp $(srcdir)/wizbit-sharp.snk.in $@
BUILT_SOURCES = AssemblyInfo.cs wizbit-sharp.snk

pkg = wizbit

EXTRA_DIST =
SNK = wizbit-sharp.snk
SYMBOLS =
INCLUDE_API =
METADATA = wizbit.metadata
references =
glue_includes =
sources =
customs =

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = wizbit-sharp.pc
add_dist = wizbit-sharp.pc.in
DISTCLEANFILES = $(pkgconfig_DATA)

include $(top_srcdir)/bindings/dotnet/Makefile.include
