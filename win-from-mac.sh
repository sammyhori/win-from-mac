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

# Prerequisites
# - A Windows ISO file (e.g., Windows 10 or Windows 11)
# - A USB drive with sufficient space
# - THE USB DIRVE WILL BE ERASED, so ensure to back up any important data
# - Ensure you have the necessary permissions to run the script and access
#   the USB drive
# - The script requires the following tools to be installed on your Mac:
#	- awk
#	- diskutil
#	- hdiutil
#	- rsync
#	- stat
# 	- wimlib (or brew, which will be used to install wimlib)
# As far as I know, apart from wimlib and brew, these tools are available by
# default on macOS.

# Usage:
# ./win-from-mac.sh <path-to-windows-iso> <output-drive>
# Be careful with the output drive, as it will be erased

set -euf -o pipefail

log() {
	echo "$1"
}

detach_iso_disk() {
	echo "Cleaning up..."
	hdiutil detach "${iso_disk}" && echo "Detached ISO disk successfully" || echo "Failed to detach ISO disk"
}

throw_error() {
	echo "$1" #stderr?
	detach_iso_disk
	exit "$2"
}

windows_iso_path=$1
output_drive=$2
output_partition_name="WINDOWS"
output_volume="/Volumes/${output_partition_name}"

# ERASE + Format???
diskutil eraseDisk MS-DOS "${output_partition_name}" MBR "${output_drive}" || throw_error "Failed to erase disk ${output_drive}" 1

hdiutil_output=$(hdiutil attach -readonly "${windows_iso_path}") || throw_error "Failed to attach ISO disk" 2
iso_disk=$(echo "${hdiutil_output}" | awk '{print $1}')
iso_volume=$(echo "${hdiutil_output}" | awk '{print $2}')

install_wim_iso_path="${iso_volume}/sources/install.wim"
install_wim_size=$(stat -f %z "${install_wim_iso_path}") || throw_error "Failed to get size of install.wim" 3

if [[ ${install_wim_size} -lt 4294967296 ]]; then # safety?
	rsync -avh --progress "${iso_volume}" "${output_volume}" || throw_error "Failed to copy ISO contents to output drive" 4
else
	rsync -avh --progress --exclude=sources/install.wim "${iso_volume}/" "${output_volume}/" || throw_error "Failed to copy ISO contents to output drive, excluding install.wim" 5
	if ! type wimlib &> /dev/null; then
		brew install wimlib || throw_error "Failed to install wimlib" 6
	fi
	wimlib-imagex split "${install_wim_iso_path}" "${output_volume}/sources/install.swm" 3800 || throw_error "Failed to split install.wim, ensure \`wimlib\` is not an aliased command" 7
fi

sync

detach_iso_disk
diskutil unmount "${output_volume}" && echo "Unmounted output drive" || echo "Failed to unmount output drive"
