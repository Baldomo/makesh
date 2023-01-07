#!/usr/bin/bash
#
#   message.sh - functions for outputting messages in makepkg
#
#   Copyright (c) 2006-2021 Pacman Development Team <pacman-dev@archlinux.org>
#   Copyright (c) 2002-2006 by Judd Vinet <jvinet@zeroflux.org>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Tries to activate terminal color sequences.
msg::colorize() {
	# prefer terminal safe colored and bold text when tput is supported
	if tput setaf 0 &>/dev/null; then
		ALL_OFF="$(tput sgr0)"
		BOLD="$(tput bold)"
		BLUE="${BOLD}$(tput setaf 4)"
		GREEN="${BOLD}$(tput setaf 2)"
		RED="${BOLD}$(tput setaf 1)"
		YELLOW="${BOLD}$(tput setaf 3)"
	else
		ALL_OFF="\e[0m"
		BOLD="\e[1m"
		BLUE="${BOLD}\e[34m"
		GREEN="${BOLD}\e[32m"
		RED="${BOLD}\e[31m"
		YELLOW="${BOLD}\e[33m"
	fi
	readonly ALL_OFF BOLD BLUE GREEN RED YELLOW
}

# Primarily used to continue a previous message on a new line.
msg::plain() {
	(( QUIET )) && return
	local mesg=$1; shift
	# shellcheck disable=SC2059
	printf "${BOLD}    ${mesg}${ALL_OFF}\n" "$@"
}

# Primarily used to continue a previous error on a new line.
msg::plainerr() {
	msg::plain "$@" >&2
}

# A standard output message.
msg::msg() {
	(( QUIET )) && return
	local mesg=$1; shift
	# shellcheck disable=SC2059
	printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@"
}

# An indented output message.
msg::msg2() {
	(( QUIET )) && return
	local mesg=$1; shift
	# shellcheck disable=SC2059
	printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@"
}

# Used to ask for user input.
msg::ask() {
	local mesg=$1; shift
	# shellcheck disable=SC2059
	printf "${BLUE}::${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}" "$@"
}

# A warning message.
msg::warning() {
	local mesg=$1; shift
	# shellcheck disable=SC2059
	printf "${YELLOW}==> WARNING:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

# An error message with function name reporting. Will NOT stop execution.
msg::error() {
	local mesg=$1; shift
	# shellcheck disable=SC2059
	printf "${RED}==> ERROR:${ALL_OFF}${BOLD} (${FUNCNAME[1]}) ${mesg}${ALL_OFF}\n" "$@" >&2
}

# An critical error message with function name reporting. WILL stop execution.
msg::die() {
	local mesg=$1; shift
	# shellcheck disable=SC2059
	printf "${RED}==> ERROR:${ALL_OFF}${BOLD} (${FUNCNAME[1]}) ${mesg}${ALL_OFF}\n" "$@" >&2
	exit 1
}
