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

# Space-delimited list of supported branches, lowest listed first
# (comment out if all current branches are supported)
# NB! This variable must be declared *above* inclusion of this snippet
#DEB_SUGAR_BRANCHES = 0.84 0.86

# FIXME: move these to buildvars.mk
comma = ,
cdbs_delimit = $(firstword $1)$(foreach word,$(wordlist 2,$(words $1),$1),$2$(word))

# List "packages multiplied with branches", or just packages if no branches
# FIXME: move this to buildvars.mk
cdbs_expand_branches = $(subst WORDDELIMITER,$3,$(subst BRANCHDELIMITER,$4,$(call cdbs_delimit,$(if $2,$(foreach pkg,$1,$(call cdbs_delimit,$(foreach branch,$2,$(pkg)$(branch:%=-%)),BRANCHDELIMITER)),$1),WORDDELIMITER)))

# convenience wrappers to expand Sugar branches for package dependencies
cdbs_sugar_allbranchdeps = $(call cdbs_expand_branches,$1,$(DEB_SUGAR_BRANCHES),$(comma) ,$(comma) )
cdbs_sugar_anybranchdeps = $(call cdbs_expand_branches,$1,$(DEB_SUGAR_BRANCHES),$(comma) , | )

# Declare Build-Deps for packages using this file
CDBS_BUILD_DEPENDS := $(CDBS_BUILD_DEPENDS), $(call cdbs_sugar_anybranchdeps,python-sugar python-sugar-toolkit), unzip
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

# TODO: Move this to buildvars.mk
cdbs_pkgsrcdir = $(if $(DEB_PKGSRCDIR_$(cdbs_curpkg)),$(DEB_PKGSRCDIR_$(cdbs_curpkg)),$(DEB_SRCDIR))

pre-build::
	mkdir -p debian/stamps-configure

$(patsubst %,build/%,$(DEB_PYTHON_SUGAR_PACKAGES)) :: build/%:
	[ ! -e $(cdbs_pkgsrcdir)/MANIFEST ] || [ -e $(cdbs_pkgsrcdir)/MANIFEST.upstream ] || mv $(cdbs_pkgsrcdir)/MANIFEST $(cdbs_pkgsrcdir)/MANIFEST.upstream
	[ ! -e $(cdbs_pkgsrcdir)/MANIFEST.upstream ] || egrep -v '^locale/.*/(.*\.mo|activity\.linfo)$$' $(cdbs_pkgsrcdir)/MANIFEST.upstream > $(cdbs_pkgsrcdir)/MANIFEST
	for pythonver in $(cdbs_python_build_versions); do \
		/usr/bin/python$$ver $(cdbs_pkgsrcdir)/setup.py build; \
	done
	[ ! -e $(cdbs_pkgsrcdir)/MANIFEST.upstream ] || IFS="`printf '\n'`" find "$(cdbs_pkgsrcdir)/locale" -type f \( -name '*.mo' -or -name 'activity.linfo' \) | while read path; do \
		echo "$$path" | sed 's!^$(cdbs_pkgsrcdir)/!!' >> $(cdbs_pkgsrcdir)/MANIFEST; \
	done

$(patsubst %,install/%,$(DEB_PYTHON_SUGAR_PACKAGES)) :: install/%:
	mkdir -p $(DEB_DESTDIR)usr/share/sugar/activities
	for pythonver in $(cdbs_python_build_versions); do \
		LANG=C /usr/bin/python$$ver $(cdbs_pkgsrcdir)/setup.py install --prefix="$(DEB_DESTDIR)/usr"; \
	done

$(patsubst %,binary-install/%,$(DEB_PYTHON_SUGAR_PACKAGES)) :: binary-install/%:
ifeq (pysupport, $(DEB_PYTHON_SYSTEM))
	dh_pysupport -p$(cdbs_curpkg) $(DEB_PYTHON_PRIVATE_MODULES_DIRS) $(DEB_PYTHON_PRIVATE_MODULES_DIRS_$(cdbs_curpkg))
else
	dh_pycentral -p$(cdbs_curpkg)
endif

reverse-config:: $(patsubst %,cleanpythonsugar-reverse-config/%,$(DEB_PYTHON_SUGAR_PACKAGES))
$(patsubst %,cleanpythonsugar-reverse-config/%,$(DEB_PYTHON_SUGAR_PACKAGES)) :: cleanpythonsugar-reverse-config/% : 
	[ ! -e $(cdbs_pkgsrcdir)/MANIFEST.upstream ] || mv -f $(cdbs_pkgsrcdir)/MANIFEST.upstream $(cdbs_pkgsrcdir)/MANIFEST

clean:: $(patsubst %,cleanpythonsugar/%,$(DEB_PYTHON_SUGAR_PACKAGES))
ifeq (, $(cdbs_selected_pycompat))
	echo "$(cdbs_pycompat)" >debian/pycompat
endif # use pycompat

$(patsubst %,cleanpythonsugar/%,$(DEB_PYTHON_SUGAR_PACKAGES)) :: cleanpythonsugar/% : 
	-IFS="`printf '\n'`" find "$(cdbs_pkgsrcdir)/locale" -type f \( -name '*.mo' -or -name 'activity.linfo' \) | while read path; do \
		rm -f "$$path"; \
		rmdir --ignore-fail-on-non-empty "`dirname "$$path"`"; \
	done
	-rmdir --ignore-fail-on-non-empty "$(cdbs_pkgsrcdir)/locale"

## TODO: Drop this when DEB_PYTHON_PACKAGES is only resolved in build targets
pre-build clean::
	$(cdbs_python_pkgresolve_check)

endif
