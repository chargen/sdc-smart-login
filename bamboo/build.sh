#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2014, Joyent, Inc.
#

set -e

DIRNAME=$(cd `dirname $0`; pwd)
gmake clean && gmake lint && gmake

NAME=smartlogin
BRANCH=$(git symbolic-ref HEAD | cut -d'/' -f3)
DESCRIBE=$(git describe)
BUILDSTAMP=`TZ=UTC date "+%Y%m%dT%H%M%SZ"`; export BUILDSTAMP
PKG=${NAME}-${BRANCH}-${BUILDSTAMP}-${DESCRIBE}.tgz

if [[ $( echo $BRANCH | grep release) && -z $PUBLISH_LOCATION ]]; then
    releasedate=$(echo $BRANCH | cut -d '-' -f2)
    RELEASEDIR=${releasedate:0:4}-${releasedate:4:2}-${releasedate:6:2}
    PUBLISH_LOCATION=/rpool/data/coal/releases/${RELEASEDIR}/deps/agents/smartlogin/${BRANCH}/
fi

if [[ -z $PUBLISH_LOCATION ]]; then
    PUBLISH_LOCATION=/rpool/data/coal/live_147/agents/smartlogin/${BRANCH}/
fi
if [[ `hostname` = 'bh1-autobuild' ]]; then
    DO_PUBLISH=1;
fi

source $DIRNAME/publish.sh
