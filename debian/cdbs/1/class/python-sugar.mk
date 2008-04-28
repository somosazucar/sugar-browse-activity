# -*- mode: makefile; coding: utf-8 -*-
# Copyright © 2008 Jonas Smedegaard <dr@jones.dk>
# Description: Class to build and install Sugar packages
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02111-1307 USA.
#

_cdbs_scripts_path ?= /usr/lib/cdbs
_cdbs_rules_path ?= /usr/share/cdbs/1/rules
_cdbs_class_path ?= /usr/share/cdbs/1/class

ifndef _cdbs_class_python_sugar
_cdbs_class_python_sugar = 1

#include $(_cdbs_class_path)/python-vars.mk$(_cdbs_makefile_suffix)
include debian/cdbs/1/class/python-vars.mk
include $(_cdbs_rules_path)/debhelper.mk$(_cdbs_makefile_suffix)

# Declare Build-Deps for packages using this file
CDBS_BUILD_DEPENDS := $(CDBS_BUILD_DEPENDS), python-sugar, python-sugar-toolkit (>= 0.79.6-2~), unzip
# FIXME: Resolve DEB_PYTHON_PACKAGES in build targets only
ifeq (,$(cdbs_python_pkg_check)$(DEB_PYTHON_ARCH_PACKAGES))
  ifneq (, $(cdbs_python_compile_version))
    CDBS_BUILD_DEPENDS := $(CDBS_BUILD_DEPENDS), python$(cdbs_python_compile_version)-dev, python (>= 2.3.5-11)
  else
    CDBS_BUILD_DEPENDS := $(CDBS_BUILD_DEPENDS), python-dev (>= 2.3.5-11)
  endif
else
CDBS_BUILD_DEPENDS := $(CDBS_BUILD_DEPENDS), python-all-dev (>= 2.3.5-11)
endif
ifeq (pysupport, $(DEB_PYTHON_SYSTEM))
CDBS_BUILD_DEPENDS := $(CDBS_BUILD_DEPENDS), python-support (>= 0.3.2)
else
CDBS_BUILD_DEPENDS := $(CDBS_BUILD_DEPENDS), python-central (>= 0.5.6)
endif

DEB_PYTHON_SUGAR_PACKAGES = $(filter sugar-%-activity, $(DEB_PACKAGES))

# Files or `find -name`-compatible search patterns to add to temp MANIFEST
#DEB_PYTHON_SUGAR_MANIFEST = *.py *.po *.pot *.svg

DEB_PYTHON_SUGAR_MANIFEST_REGEX =
DEB_PYTHON_SUGAR_MANIFEST_IGNORE_REGEX = ^debian/.*

# TODO: Move this to buildvars.mk
cdbs_pkgsrcdir = $(if $(DEB_PKGSRCDIR_$(cdbs_curpkg)),$(DEB_PKGSRCDIR_$(cdbs_curpkg)),$(DEB_SRCDIR))

cdbs_python_sugar_manifest_files_tmp = $(patsubst %,-or -name '%',$(DEB_PYTHON_SUGAR_MANIFEST))
cdbs_python_sugar_manifest_files = $(wordlist 2, $(words $(cdbs_python_sugar_manifest_files_tmp)), $(cdbs_python_sugar_manifest_files_tmp))

cdbs_python_sugar_automanifest = $(if $(DEB_PYTHON_SUGAR_MANIFEST_$(cdbs_curpkg)),$(DEB_PYTHON_SUGAR_MANIFEST_$(cdbs_curpkg)),$(DEB_PYTHON_SUGAR_MANIFEST))

pre-build::
	mkdir -p debian/stamps-configure

# FIXME: make these targets *not* run twice but respect stamps!
$(patsubst %,configure/%,$(DEB_PYTHON_SUGAR_PACKAGES)) :: configure/%: debian/stamps-configure/%
$(patsubst %,debian/stamps-configure/%,$(DEB_PYTHON_SUGAR_PACKAGES)) :: debian/stamps-configure/%:
	$(if $(cdbs_python_sugar_automanifest),i="$(cdbs_pkgsrcdir)/MANIFEST"; if [ -e "$$i" ] && [ ! -e "$$i.cdbs-orig" ]; then mv "$$i" "$$i.cdbs-orig"; fi)
	$(if $(cdbs_python_sugar_automanifest),cd "$(cdbs_pkgsrcdir)" && find * -type f $(if $(cdbs_python_sugar_manifest_files)$(DEB_PYTHON_SUGAR_MANIFEST_REGEX),'(' $(cdbs_python_sugar_manifest_files) $(if $(DEB_PYTHON_SUGAR_MANIFEST_REGEX),$(if $(cdbs_python_sugar_manifest_files),-or )-regex '$(DEB_PYTHON_SUGAR_MANIFEST_REGEX)') ')') $(if $(DEB_PYTHON_SUGAR_MANIFEST_IGNORE_REGEX),-not -regex '$(DEB_PYTHON_SUGAR_MANIFEST_IGNORE_REGEX))' > "$(cdbs_pkgsrcdir)/MANIFEST")
	touch $@

$(patsubst %,build/%,$(DEB_PYTHON_SUGAR_PACKAGES)) :: build/%:
	for pythonver in $(cdbs_python_build_versions); do \
		/usr/bin/python$$ver $(cdbs_pkgsrcdir)/setup.py dist; \
	done

$(patsubst %,install/%,$(DEB_PYTHON_SUGAR_PACKAGES)) :: install/%:
	mkdir -p $(DEB_DESTDIR)usr/share/activities
	for pythonver in $(cdbs_python_build_versions); do \
		/usr/bin/python$$ver $(cdbs_pkgsrcdir)/setup.py install $(DEB_DESTDIR)usr/share/activities; \
	done

$(patsubst %,binary-install/%,$(DEB_PYTHON_SUGAR_PACKAGES)) :: binary-install/%:
ifeq (pysupport, $(DEB_PYTHON_SYSTEM))
	dh_pysupport -p$(cdbs_curpkg) $(DEB_PYTHON_PRIVATE_MODULES_DIRS) $(DEB_PYTHON_PRIVATE_MODULES_DIRS_$(cdbs_curpkg))
else
	dh_pycentral -p$(cdbs_curpkg)
endif

clean:: $(patsubst %,cleanpythonsugar/%,$(DEB_PYTHON_SUGAR_PACKAGES))
ifeq (, $(cdbs_selected_pycompat))
	echo "$(cdbs_pycompat)" >debian/pycompat
endif # use pycompat
	rm -rf debian/stamps-configure

$(patsubst %,cleanpythonsugar/%,$(DEB_PYTHON_SUGAR_PACKAGES)) :: cleanpythonsugar/% : 
	for pythonver in $(cdbs_python_build_versions); do \
		/usr/bin/python$$ver $(cdbs_pkgsrcdir)/setup.py clean; \
	done
	find "$(cdbs_pkgsrcdir)" -maxdepth 1 -type f -name '*.xo' -exec rm -f '{}' ';'
	-IFS="`printf '\n'`" find "$(cdbs_pkgsrcdir)/locale" -type f \( -name '*.mo' -or -name 'activity.linfo' \) | while read path; do \
		rm -f "$$path"; \
		rmdir --ignore-fail-on-non-empty "`dirname "$$path"`"; \
	done
	-rmdir --ignore-fail-on-non-empty "$(cdbs_pkgsrcdir)/locale"
	$(if $(cdbs_python_sugar_automanifest),i="$(cdbs_pkgsrcdir)/MANIFEST"; if test -e "$$i.cdbs-orig"; then mv -f "$$i.cdbs-orig" "$$i"; fi)

## TODO: Drop this when DEB_PYTHON_PACKAGES is only resolved in build targets
pre-build clean::
	$(cdbs_python_pkgresolve_check)

endif
