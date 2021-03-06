#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2014, Joyent, Inc.
#

# Smartlogin Makefile

NAME=smartlogin
TOP := $(shell pwd)

# Need GNU awk for multi-char arg to "-F".
AWK=$(shell (which gawk 2>/dev/null | grep -v "^no ") || which awk)
BRANCH=$(shell git symbolic-ref HEAD | $(AWK) -F/ '{print $$3}')
ifeq ($(TIMESTAMP),)
	TIMESTAMP=$(shell date -u "+%Y%m%dT%H%M%SZ")
endif
GITDESCRIBE=g$(shell git describe --all --long --dirty | $(AWK) -F'-g' '{print $$NF}')
BASE=$(NAME)-$(BRANCH)-$(TIMESTAMP)-$(GITDESCRIBE)
TARBALL=$(BASE).tgz
MANIFEST=$(BASE).manifest


CC	= gcc
CCFLAGS	= -fPIC -g -Wall -Werror -I$(TOP)/hack-platform-include
LDFLAGS	= -nodefaultlibs -L/lib -L/usr/lib -lc -lnvpair

AGENT := ${NAME}
AGENT_SRC = \
	src/agent/bunyan.c 	\
	src/agent/capi.c 	\
	src/agent/config.c 	\
	src/agent/hash.c 	\
	src/agent/list.c	\
	src/agent/lru.c		\
	src/agent/nvpair_json.c	\
	src/agent/server.c	\
	src/agent/util.c	\
	src/agent/zutil.c

# ARG! Some versions of solaris have curl 3, some curl 4,
# so pick up the specific version
AGENT_LIBS = -lzdoor -lzonecfg /usr/lib/libcurl.so.4

NPM_FILES =		\
	bin		\
	etc		\
	npm-scripts

include ./tools/mk/Makefile.gitdefs

.PHONY: all clean distclean npm

all:: npm

${AGENT}:
	mkdir -p bin
	${CC} ${CCFLAGS} ${LDFLAGS} -o bin/$@ $^ ${AGENT_SRC} ${AGENT_LIBS}
	if /usr/bin/elfdump -d bin/$@ | egrep 'RUNPATH|RPATH'; then \
		echo "Your compiler is inserting an errant RPATH/RUNPATH" >&2; \
		exit 1; \
	fi

lint:
	for file in ${AGENT_SRC} ; do \
		echo $$file ; \
		lint -Isrc/agent -uaxm -m64 $$file ;  \
		echo "--------------------" ; \
	done

$(TARBALL): ${AGENT} $(NPM_FILES) package.json
	rm -fr .npm
	mkdir -p .npm/$(NAME)/
	cp -Pr $(NPM_FILES) .npm/$(NAME)/
	uuid -v4 > .npm/$(NAME)/image_uuid
	json -f package.json -e 'this.version += "-$(STAMP)"' \
	    > .npm/$(NAME)/package.json
	(cd .npm && gtar zcvf ../$(TARBALL) $(NAME))
	cat $(TOP)/manifest.tmpl | sed \
		-e "s/UUID/$$(cat .npm/$(NAME)/image_uuid)/" \
		-e "s/NAME/$$(json name < .npm/$(NAME)/package.json)/" \
		-e "s/VERSION/$$(json version < .npm/$(NAME)/package.json)/" \
		-e "s/DESCRIPTION/$$(json description < .npm/$(NAME)/package.json)/" \
		-e "s/BUILDSTAMP/$(STAMP)/" \
		-e "s/SIZE/$$(stat --printf="%s" $(TARBALL))/" \
		-e "s/SHA/$$(openssl sha1 $(TARBALL) \
		    | cut -d ' ' -f2)/" \
		> $(MANIFEST)

npm: $(TARBALL)

# The "publish" target requires that "BITS_DIR" be defined.
# The target will then publish to "$BITS_DIR/smartlogin/".
publish: $(BITS_DIR)
	@if [[ -z "$(BITS_DIR)" ]]; then \
		echo "error: 'BITS_DIR' must be set for 'publish' target"; \
		exit 1; \
	fi
	mkdir -p $(BITS_DIR)/smartlogin
	cp $(TARBALL) $(BITS_DIR)/smartlogin/
	cp $(MANIFEST) $(BITS_DIR)/smartlogin/

clean:
	-rm -rf bin .npm core $~ smartlogin*.tgz ${AGENT}
	find . -name *.o | xargs rm -f

distclean: clean
