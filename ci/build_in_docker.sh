#!/bin/bash
# FILE:    ci/build_in_docker.sh
# CONTEXT: Build diskquota and package it as a .deb in container
# PURPOSE: 

# Fot build in docker using stable Greengage images:
# GGDB_IMAGE=greengagedb/ggdb6_ubuntu:latest
# GGDB_IMAGE=greengagedb/ggdb6_ubuntu24:latest
# GGDB_IMAGE=greengagedb/ggdb7_ubuntu:latest
#
# or developer Greengage images:
# GGDB_IMAGE=ghcr.io/greengagedb/greengage/ggdb6_ubuntu:latest
# GGDB_IMAGE=ghcr.io/greengagedb/greengage/ggdb7_ubuntu:latest

# shellcheck disable=SC2086

# USAGE:
# export GP_MAJORVERSION=6
# export PG_HOME=/opt/greengagedb/greengage${GP_MAJORVERSION}
# export GGDB_IMAGE=ghcr.io/greengagedb/greengage/ggdb${GP_MAJORVERSION}_ubuntu:latest
# export SRC=/home/gpadmin/diskquota
# docker run --rm -it -v ./:$SRC -w $SRC -e SRC -e PG_HOME -e GP_MAJORVERSION $GGDB_IMAGE ci/build_in_docker.sh

set -eux

is_container() {
    [[ -f /.dockerenv || -f /run/.containerenv ]] ||
        grep -qE '(docker|containerd|libpod|podman|kubepods)' \
            /proc/1/cgroup 2>/dev/null
}

if ! is_container; then
    echo "WARNING: This script is designed to run in a container."
    echo "Running it directly on the host system may modify the system unexpectedly."
    read -r -p "Continue anyway? [y/N] " answer

    [[ "$answer" =~ ^[Yy]$ ]] || exit 1
fi

: "${PG_HOME:?PG_HOME must be set}"

export DEBIAN_FRONTEND=noninteractive
export GP_MAJORVERSION=${GP_MAJORVERSION:-6}
export GREENGAGE_PACKAGE=${GREENGAGE_PACKAGE:-greengage$GP_MAJORVERSION}

# Configure
git config --system --add safe.directory "$(pwd)"

update-locale LANG=en_US.UTF-8
localedef -c -i ru_RU -f CP1251 ru_RU.CP1251

# Install packages from apt
echo -n "Installing packages via apt... "
{
  # shellcheck disable=SC1091 # External source
  apt-get -yq update
  apt-get -yq install --no-install-recommends "$GREENGAGE_PACKAGE"
  apt-get clean
} 1>/dev/null ; echo "Done"

# GreengageDB environment variables
export PYTHONPATH="$PG_HOME/lib/python"
export LD_LIBRARY_PATH="$PG_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# shellcheck disable=SC1091 # External source
source "$PG_HOME/greengage_path.sh"

if [ -e "$PG_HOME/etc/openssl.cnf" ]; then
	export OPENSSL_CONF="$PG_HOME/etc/openssl.cnf"
fi

# Package
make -f package.mk pkg
