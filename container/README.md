<!--
 - SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
 - SPDX-License-Identifier: AGPL-3.0-only
-->
# Setup osh-tool in container

cd /tmp
git clone --quiet --branch=0.5.0 --depth=1 --recursive https://github.com/hoijui/osh-tool
cd osh-tool
docker build --tag osh-tool .

# Setup gitbuilding in container

cd workspace/container/gitbuilding
docker build --tag gitbuilding . -f Containerfile
