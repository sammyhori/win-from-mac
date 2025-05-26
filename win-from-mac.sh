#!/bin/zsh

## win-from-mac: for creating a bootable Windows USB from a MacOS system.
## Copyright (C) 2025  Sammy Hori
##
## This program is free software: you can redistribute it and/or modify it
## under the terms of the GNU General Public License version 3, as published
## by the Free Software Foundation.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <https://www.gnu.org/licenses/>.

# This script is for creating a bootable Windows USB drive from a Windows ISO
# file on a MacOS system. This can then be used to install Windows on a PC.
# It is designed to be run from a macOS terminal.
# It requires the following tools:
# - wimlib
# - diskutil
# - hdiutil
# - rsync
# - stat
# - awk
# - brew (for installing wimlib if not already installed)

# Usage:
# ./win-from-mac.sh <path-to-windows-iso> <output-drive>
# e.g. 
# Be careful with the output drive, as it will be erased

set -euf -o pipefail

set -x

log() {
	echo "$1"
}

clean-up() {
	echo "Cleaning up..."
	hdiutil detach "${iso_disk}" && echo "Detached ISO disk successfully" || echo "Failed to detach ISO disk"
}

throw-error() {
	echo "$1" #stderr?
	clean-up
	exit "$2"
}

windows_iso_path=$1
output_drive=$2
output_partition_name="WINDOWS"
output_volume="/Volumes/${output_partition_name}"

# ERASE + Format???
diskutil eraseDisk MS-DOS "${output_partition_name}" MBR "${output_drive}" || throw-error "Failed to erase disk ${output_drive}" 1

hdiutil_output=$(hdiutil attach -readonly "${windows_iso_path}") || throw-error "Failed to attach ISO disk" 1
iso_disk=$(echo "${hdiutil_output}" | awk '{print $1}')
iso_volume=$(echo "${hdiutil_output}" | awk '{print $2}')

install_wim_iso_path="${iso_volume}/sources/install.wim"
install_wim_size=$(stat -f %z "${install_wim_iso_path}")

if [[ ${install_wim_size} -lt 4294967296 ]]; then # safety?
	rsync -avh --progress "${iso_volume}" "${output_volume}"
else
	rsync -avh --progress --exclude=sources/install.wim "${iso_volume}/" "${output_volume}/"
	if ! type wimlib &> /dev/null; then
		brew install wimlib || throw-error "Failed to install wimlib" 2
	fi
	wimlib-imagex split "${install_wim_iso_path}" "${output_volume}/sources/install.swm" 3800 || throw-error "Failed to split install.wim, ensure \`wimlib\` is not an aliased command" 3
fi

sync

clean-up
diskutil unmount "${output_volume}" && echo "Unmounted output drive" || echo "Failed to unmount output drive"

set +x
