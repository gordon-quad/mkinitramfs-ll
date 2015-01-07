#!/bin/bash
#
# $Header: mkinitramfs-ll/busybox.bash                   Exp $
# $Author: (c) 2011-2015 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.16.0 2015/01/01 12:33:03                   Exp $
#
declare -A PKG
PKG=(
	[name]=busybox
	[shell]=bash
	[version]=0.16.0
)

# @FUNCTION: usage
# @DESCRIPTION: print usages message
function usage {
  cat <<-EOH
  ${PKG[name]}.${PKG[shell]}-${PKG[version]}
  usage: ${PKG[name]}.${PKG[shell]} [options]

  -d, --usrdir=usr       USRDIR to use (where to copy BusyBox binary)
  -n, --minimal          Build only with minimal applets support
  -a, --abi=i386         Set ABI to use when building against uClibc
  -v, --version=1.20.0   Set version to build instead of latest
  -h, --help, -?         Print the help message and exit
EOH
exit $?
}

# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
function error {
	echo -ne " \e[1;31m* \e[0m${PKG[name]}.${PKG[shell]}: $@\n" >&2
}
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
function die {
	local ret=$?
	error "$@"
	exit $ret
}

declare -A opts
declare -a opt

opt=(
	"-o" "?a:hnd::v:"
	"-l" "abi:,help,minimal,usrdir::,version:"
	"-n" "${PKG[name]}.${PKG[shell]}"
	"-s" "${PKG[shell]}"
)
opt=($(getopt "${opt[@]}" -- "$@" || usage))
eval set -- "${opt[@]}"

for (( ; $# > 0; )); do
	case $1 in
		(-n|--minimal)
			opts[-minimal]=true
			shift;;
		(-a|--abi)
			opts[-abi]="$2"
			shift 2;;
		(-d|--usrdir)
			opts[-usrdir]="$2"
			shift 2;;
		(-v|--version)
			opts[-version]="$2"
			shift 2;;
		(--)
			shift
			break;;
		(-?|-h|--help|*)
			usage;;
	esac
done

[[ -f /etc/portage/make.conf ]] && source /etc/portage/make.conf ||
	die "no /etc/portage/make.conf found"

# @VARIABLE: opts[-usrdir]
# @DESCRIPTION: usr directory, where to get extra files
[[ "${opts[-usrdir]}" ]] || opts[-usrdir]="${PWD}"/usr
# @VARIABLE: opts[-version]
# @DESCRIPTION: GnuPG version to build
#
# @VARIABLE: opts[-pkg]
# @DESCRIPTION: busybox version to build
opts[-pkg]=busybox

if [[ "${opts[-version]}" ]]; then
:	opts[-pkg]=${opts[-pkg]}-${opts[-version]}
else
	opts[-pkg]=$(emerge -pvO ${opts[-pkg]} | grep -o "busybox-[-0-9.r]*")
fi

mkdir -p "${opts[-usrdir]}"/bin

pushd "${PORTDIR:-/usr/portage}"/sys-apps/busybox || die
ebuild ${opts[-pkg]}.ebuild clean || die "clean failed"
ebuild ${opts[-pkg]}.ebuild unpack || die "unpack failed"
pushd "${PORTAGE_TMPDIR:-/var/tmp}"/portage/sys-apps/${opts[-pkg]}/work/${opts[-pkg]} || die

if [[ "${opts[-minimal]}" ]]; then
	make allnoconfig || die
	while read cfg; do
		sed -e "s|# ${cfg%'=y'} is not set|${cfg}|" -i .config || die 
	done <"${0%/*}"/busybox-minimal.config
else
	make defconfig || die "defconfig failed"
	sed -e "s|# CONFIG_STATIC is not set|CONFIG_STATIC=y|" \
		-e "s|# CONFIG_INSTALL_NO_USR is not set|CONFIG_INSTALL_NO_USR=y|" \
		-i .config || die
fi

if [[ "${opts[-abi]}" ]]; then
	sed -e "s|CONFIG_CROSS_COMPILER_PREFIX=\"\"|CONFIG_CROSS_COMPILER_PREFIX=\"${opts[-abi]}\"|" \
		-i .config || die "setting uClib ARCH failed"
fi

make || die "failed to build busybox"
cp -a busybox "${opts[-usrdir]}"/bin/ || die

popd || die
ebuild ${opts[-pkg]}.ebuild clean || die

unset -v opts PKG

#
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
#
