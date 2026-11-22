#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# 20261121 (c) William Fonkou Tambe

function usage {
	cat << __EOF__
usage: $(basename "${0}") [options] <image>

	Utility that creates a standard BIOS partition table on <image>
	writing it with boot-code and up to four primary partitions.

	Each partition is written in the slot of its option: when a slot is
	not specified but a later one is, it gets a one-sector placeholder
	of type 0x00.

	A partition file can be prefixed with its MBR partition type in hex
	followed by a colon (e.g. -4 0x83:rootfs.ext2); otherwise the default
	type of its slot is used. A file whose name starts like such a prefix
	can be given as ./<file>.

options:

-0 <file>
	boot-code to write in <image> first 440 bytes; it may be up to
	512 bytes, but bytes 440-511 are replaced by the MBR disk signature
	and partition table.
	If not specified, nothing is used.

-1 [<type>:]<file>
	data to write in <image> first partition; default type 0x0c.
	If not specified, an empty 32 MiB FAT filesystem of type 0x0c is used.

-2 [<type>:]<file>
	data to write in <image> second partition; default type 0xf8.
	If not specified, nothing is used.

-3 [<type>:]<file>
	data to write in <image> third partition; default type 0x8a.
	If not specified, nothing is used.

-4 [<type>:]<file>
	data to write in <image> fourth partition; default type 0x83.
	If not specified, nothing is used.

-h
	Show this help.
__EOF__
}

# Print error $1 and exit; with a second argument, also print the usage.
function die {
	echo "error: $1" >&2
	[ $# -lt 2 ] || usage >&2
	exit 1
}

imgfile=""
# Files given with -0 to -4: slot 0 is the boot-code, 1 to 4 the partitions.
slot=("" "" "" "" "")
# Default partition type of slots 1 to 4, and the type used for each slot.
deftype=("" 0x0c 0xf8 0x8a 0x83)
slottype=("${deftype[@]}")
# Partition type prefix of a file: 0x, hex digits and a colon.
typere='^0[xX]([0-9a-fA-F]+):(.*)$'

while [ $# -gt 0 ]; do
	case "$1" in
		-[0-4])
			[ -n "$2" ] || die "option $1 requires an argument" usage
			n="${1#-}"
			f="$2"
			slottype[n]="${deftype[n]}"
			if [[ ${f} =~ ${typere} ]]; then
				(( n > 0 )) || die "option -0 takes no partition type: ${f}"
				(( ${#BASH_REMATCH[1]} <= 2 )) || die "invalid partition type: 0x${BASH_REMATCH[1]}"
				slottype[n]="$(printf '0x%02x' "$(( 16#${BASH_REMATCH[1]} ))")"
				f="${BASH_REMATCH[2]}"
				[ -n "${f}" ] || die "option $1 is missing a file after its partition type" usage
			fi
			slot[n]="${f}"
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		-*)
			die "invalid option: $1" usage
			;;
		*)
			[ -z "${imgfile}" ] || die "invalid extra argument: $1" usage
			imgfile="$1"
			;;
	esac
	shift
done

[ -n "${imgfile}" ] || die "image file missing" usage

for n in 0 1 2 3 4; do
	f="${slot[n]}"
	[ -z "${f}" ] || { [ -f "${f}" ] && [ -r "${f}" ] && [ -s "${f}" ]; } ||
		die "-${n} file missing, unreadable or empty: ${f}"
done

# The boot-code must fit in the MBR sector; a bigger file is most likely
# the wrong one (e.g. an ELF file instead of the raw binary).
if [ -n "${slot[0]}" ] && (( $(wc -c < "${slot[0]}") > 512 )); then
	die "-0 file larger than 512 bytes: ${slot[0]}"
fi

# Last partition slot to write; slot 1 is always written.
last=1
for n in 2 3 4; do
	[ -n "${slot[n]}" ] && last="${n}"
done

set -x

tmpdir="$(mktemp -d)" || die "mktemp failed"
trap 'rm -rf "${tmpdir}"' EXIT
mkdir -p "${tmpdir}/tmp"

# Print $1 as a genimage config string: \ " and $ are escaped, otherwise
# genimage (libconfuse) would e.g. expand ${HOME} found in a file name.
function cfgstr {
	printf '"%s"' "$(printf '%s' "$1" | sed -e 's/[\\"$]/\\&/g')"
}

# Print partition $1 of type $2 holding image $3; without an image, print
# a one-sector placeholder of type 0x00 that only holds the slot.
function cfgpart {
	if [ -n "$3" ]; then
		cat << __EOF__

  partition $1 {
    partition-type = $2
    image = $(cfgstr "$3")
  }
__EOF__
	else
		cat << __EOF__

  partition $1 {
    partition-type = 0x00
    size = 512
  }
__EOF__
	fi
}

{
	if [ -z "${slot[1]}" ]; then
		cat << __EOF__
image fatpart.img {
  vfat {}
  empty = true
  temporary = true
  size = 32M
}

__EOF__
	fi

	cat << __EOF__
image $(cfgstr "$(basename -- "${imgfile}")") {
  hdimage {
    partition-table-type = "mbr"
    fill = true
  }
__EOF__

	if [ -n "${slot[0]}" ]; then
		cat << __EOF__

  partition bootcode {
    in-partition-table = false
    offset = 0
    image = $(cfgstr "$(realpath -- "${slot[0]}")")
    holes = {"(440; 512)"}
  }
__EOF__
	fi

	for (( n = 1; n <= last; n++ )); do
		if [ -n "${slot[n]}" ]; then
			cfgpart "part${n}" "${slottype[n]}" "$(realpath -- "${slot[n]}")"
		elif (( n == 1 )); then
			cfgpart part1 "${slottype[1]}" fatpart.img
		else
			cfgpart "part${n}"
		fi
	done

	echo "}"
} > "${tmpdir}/genimage.cfg"

genimage --loglevel 9 --tmppath "${tmpdir}/tmp" --outputpath "$(dirname -- "${imgfile}")" --config "${tmpdir}/genimage.cfg" ||
	die "genimage failed"

exit 0
