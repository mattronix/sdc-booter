#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2014, Joyent, Inc.
#

NAME=dhcpd

#
# Directories
#

TOP := $(shell pwd)


#
# Tools
#

NODEUNIT	:= ./node_modules/.bin/nodeunit
NPM_FLAGS = --cache=$(TOP)/build/tmp/npm-cache


#
# Files
#

BASH_FILES	:= bin/booter bin/dhcpd
JS_FILES	:= $(shell ls *.js) $(shell find lib test -name '*.js')
JSL_CONF_NODE	 = tools/jsl.node.conf
JSL_FILES_NODE   = $(JS_FILES)
JSON_FILES	:= config.json.sample package.json
JSSTYLE_FILES	 = $(JS_FILES)
SMF_MANIFESTS_IN = smf/manifests/dhcpd.xml.in smf/manifests/tftpd.xml.in
PKG_DIR = $(BUILD)/pkg
BOOTER_PKG_DIR = $(PKG_DIR)/root/opt/smartdc/booter
TFTPBOOT_PKG_DIR = $(PKG_DIR)/root/tftpboot/
RELEASE_TARBALL=dhcpd-pkg-$(STAMP).tar.bz2
CLEAN_FILES += ./node_modules build/pkg dhcpd-pkg-*.tar.bz2
REPO_MODULES := src/node-pack
JSSTYLE_FLAGS = -o indent=4,doxygen,unparenthesized-return=0

ifeq ($(shell uname -s),SunOS)
	# Allow building on a SmartOS image other than sdc-smartos/1.6.3.
	NODE_PREBUILT_IMAGE=fd2cc906-8938-11e3-beab-4359c665ac99
	NODE_PREBUILT_VERSION=v0.8.28
	NODE_PREBUILT_TAG=zone
endif


#
# Included definitions
#

include ./tools/mk/Makefile.defs
ifeq ($(shell uname -s),SunOS)
	include ./tools/mk/Makefile.node_prebuilt.defs
else
	NPM_EXEC :=
	NPM = npm
endif
include ./tools/mk/Makefile.node_deps.defs
include ./tools/mk/Makefile.smf.defs


#
# Repo-specific targets
#

.PHONY: all
all: $(REPO_DEPS) $(SMF_MANIFESTS) | $(NODEUNIT) sdc-scripts
	$(NPM) install

$(NODEUNIT): | $(NPM_EXEC)
	$(NPM) install

.PHONY: test
test: | $(NODEUNIT)
	$(NODEUNIT) --reporter=tap test/*.test.js

#
# Packaging targets
#

.PHONY: pkg
pkg: all
	rm -rf $(PKG_DIR)
	mkdir -p $(BOOTER_PKG_DIR)/smf/manifests
	mkdir -p $(TFTPBOOT_PKG_DIR)
	cp $(TOP)/tftpboot/* $(TFTPBOOT_PKG_DIR)
	cp -PR lib \
		bin \
		server.js \
		package.json \
		sapi_manifests \
		$(BOOTER_PKG_DIR)
	cp smf/manifests/*.xml $(BOOTER_PKG_DIR)/smf/manifests
	(cd $(BOOTER_PKG_DIR) && $(NPM) install --production)
	cp -PR src/node-pack $(BOOTER_PKG_DIR)/node_modules/pack
	cp -PR $(NODE_INSTALL) $(BOOTER_PKG_DIR)/node
	rm $(BOOTER_PKG_DIR)/package.json
	mkdir -p $(PKG_DIR)/root/opt/smartdc/boot
	cp -R $(TOP)/deps/sdc-scripts/* $(PKG_DIR)/root/opt/smartdc/boot/
	cp -R $(TOP)/boot/* $(PKG_DIR)/root/opt/smartdc/boot/
	# Clean up some dev / build bits
	find $(PKG_DIR) -name "*.pyc" | xargs rm -f
	find $(PKG_DIR) -name "*.o" | xargs rm -f
	find $(PKG_DIR) -name c4che | xargs rm -rf   # waf build file
	find $(PKG_DIR) -name .wafpickle* | xargs rm -rf   # waf build file
	find $(PKG_DIR) -name .lock-wscript | xargs rm -rf   # waf build file
	find $(PKG_DIR) -name config.log | xargs rm -rf   # waf build file

release: $(RELEASE_TARBALL)

$(RELEASE_TARBALL): pkg
	(cd $(PKG_DIR); tar -jcf $(TOP)/$(RELEASE_TARBALL) root)

publish:
	@if [[ -z "$(BITS_DIR)" ]]; then \
      echo "error: 'BITS_DIR' must be set for 'publish' target"; \
      exit 1; \
    fi
	mkdir -p $(BITS_DIR)/dhcpd
	cp $(RELEASE_TARBALL) $(BITS_DIR)/dhcpd/$(RELEASE_TARBALL)


#
# Includes
#

include ./tools/mk/Makefile.deps
ifeq ($(shell uname -s),SunOS)
	include ./tools/mk/Makefile.node_prebuilt.targ
endif
include ./tools/mk/Makefile.node_deps.targ
include ./tools/mk/Makefile.smf.targ
include ./tools/mk/Makefile.targ

sdc-scripts: deps/sdc-scripts/.git
