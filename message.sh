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

# plain/plainerr are primarily used to continue a previous message on a new
# line, depending on whether the first line is a regular message or an error
# output

msg::plain() {
	(( QUIET )) && return
	local mesg=$1; shift
	# shellcheck disable=SC2059
	printf "${BOLD}    ${mesg}${ALL_OFF}\n" "$@"
}

msg::plainerr() {
	msg::plain "$@" >&2
}

msg::msg() {
	(( QUIET )) && return
	local mesg=$1; shift
	# shellcheck disable=SC2059
	printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@"
}

msg::msg2() {
	(( QUIET )) && return
	local mesg=$1; shift
	# shellcheck disable=SC2059
	printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@"
}

msg::ask() {
	local mesg=$1; shift
	# shellcheck disable=SC2059
	printf "${BLUE}::${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}" "$@"
}

msg::warning() {
	local mesg=$1; shift
	# shellcheck disable=SC2059
	printf "${YELLOW}==> $(gettext "WARNING:")${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg::error() {
	local mesg=$1; shift
	# shellcheck disable=SC2059
	printf "${RED}==> $(gettext "ERROR:")${ALL_OFF}${BOLD} (${FUNCNAME[1]}) ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg::die() {
	msg::error "$@"
	exit 1
}
