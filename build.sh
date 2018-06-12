#!/usr/bin/env bash

set -eux
set -o pipefail

GPG_PASSFILE=(/dev/shm/pass.*)

# configure debsign for PPA submission
printf 'DEBSIGN_PROGRAM="gpg --no-use-agent --no-tty --trusted-key 0x7D1110294E694719 --passphrase-file %s"\nDEBSIGN_KEYID=%s\n' "${GPG_PASSFILE[0]}" "0x7D1110294E694719" > "${HOME}/.devscripts"
export DEBFULLNAME="RJ Bergeron"
export DEBEMAIL="hewt1ojkif@gmail.com"

# well we should have chdist & madison, but if not install them.
{ type rmadison && type chdist ; } || { apt-get -qq -y update && apt-get -qq -y install devscripts ; }

# get our upstream version
upstream_version=$(rmadison libssh2-1 -u ubuntu -s bionic,bionic-security 2>/dev/null|cut -d'|' -f2|sort -V|tail -n1)
upstream_version=${upstream_version# }
upstream_version=${upstream_version% }

# create a distribution to run apt tools against without interfering with the real system
[ -e "${HOME}/.chdist/xenial" ] || chdist create xenial
sed 's/'"$(lsb_release -cs)"'/xenial/g' > "${HOME}/.chdist/xenial/etc/apt/sources.list" < /etc/apt/sources.list

# add our PPA for package checking
cp notarrjay_ubuntu_stretch_xen-on-xenial.gpg "${HOME}/.chdist/xenial/etc/apt/trusted.gpg.d/"
echo "deb http://ppa.launchpad.net/notarrjay/stretch-xen-on-xenial/ubuntu xenial main" >> "${HOME}/.chdist/xenial/etc/apt/sources.list"

# get packagelists for that so we can compare builds
chdist apt-get xenial -qq update

# cool now use the apt tools via chdist to get our already-built package version
downstream_version=$(chdist apt-cache xenial show libssh2-1 | grep Version | cut -d: -f2 | sort -V | tail -n1)
downstream_version=${downstream_version# }
downstream_version=${downstream_version% }

# if the downstream package version contains the entire upstream package version we are up to date!
case "${downstream_version}" in
  "${upstream_version}"*) : ;;
  *)
     # install backportpackage if needed and fire off
     type backportpackage || { apt-get -qq -y update && apt-get -qq -y install ubuntu-dev-tools ; }
     backportpackage -s bionic -d xenial -u ppa:notarrjay/stretch-xen-on-xenial -y libssh2
  ;;
esac
