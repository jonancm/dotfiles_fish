#!/bin/bash

set -e

DESIRED_FISH_VERSION="3.6.0"

source $(dirname ${BASH_SOURCE})/bash_utils/pkg/apt.sh
source $(dirname ${BASH_SOURCE})/bash_utils/pkg/install.sh
source $(dirname ${BASH_SOURCE})/bash_utils/pkg/uninstall.sh
source $(dirname ${BASH_SOURCE})/bash_utils/sys/detect.sh
source $(dirname ${BASH_SOURCE})/bash_utils/sys/su.sh
source $(dirname ${BASH_SOURCE})/bash_utils/term/print.sh

do_nothing() {
	echo > /dev/null
}

uninstall_fish() {
	if command -v fish &> /dev/null; then
		INSTALLED_VERSION=`detect_fish_version`
		print_caution "fish ${DESIRED_FISH_VERSION} is required, but fish ${INSTALLED_VERSION} is installed\n"
		print_info "Trying to uninstall fish ${INSTALLED_VERSION} ...\n"
		if [ "${INSTALLED_VERSION}" != "${DESIRED_FISH_VERSION}" ]; then
			uninstall_pkgs fish
		fi
	fi
}

bootstrap_debian() {
	RELEASE=$1
	if [[ -z ${RELEASE} ]]; then
		RELEASE=11
	fi
	print_title "Executing bootstrap process for Debian ...\n"
	bootstrap_apt
	# Uninstall fish if it's already installed
	uninstall_fish
	# Add PPA to install latest fish version
	print_info "Trying to add fish package repository ...\n"
	install_pkg_if_not_found curl
	install_pkg_if_not_found gpg
	if [[ ${RELEASE} -eq 11 ]]; then # workaround: in Debian 12 we have fish 3.6.0 in the official repo
		print_info "Repository: "
		echo "deb http://download.opensuse.org/repositories/shells:/fish:/release:/3/Debian_${RELEASE}/ /" | run_privileged tee /etc/apt/sources.list.d/fish_v3.list
		curl -fsSL https://download.opensuse.org/repositories/shells:fish:release:3/Debian_${RELEASE}/Release.key | gpg --dearmor | run_privileged tee /etc/apt/trusted.gpg.d/shells_fish_release_3.gpg > /dev/null
	fi
	# Install lsd using cargo
	export PATH="$PATH:$HOME/.cargo/bin"
	if ! command -v lsd &> /dev/null; then
		print_info "Trying to install lsd ...\n"
		install_pkg_if_not_found cargo
		install_pkg_if_not_found rustc
		cargo install lsd --version 0.18.0 # last crate version compatible with Debian's outdated cargo version
	fi
}

bootstrap_debian_11() {
	bootstrap_debian 11
}

bootstrap_debian_12() {
	bootstrap_debian 12
}

bootstrap_fedora() {
	print_title "Executing bootstrap process for Fedora ...\n"
	install_pkg_if_not_found util-linux-user chsh
}

bootstrap_ubuntu() {
	print_title "Executing bootstrap process for Ubuntu ...\n"
	bootstrap_apt
	# Uninstall fish if it's already installed
	uninstall_fish
	# Add PPA to install latest fish version
	print_info "Trying to add fish PPA ...\n"
	install_pkg_if_not_found software-properties-common apt-add-repository
	run_privileged apt-add-repository ppa:fish-shell/release-3
	run_privileged apt-get update
	# Install lsd using cargo
	export PATH="$PATH:$HOME/.cargo/bin"
	if ! command -v lsd &> /dev/null; then
		print_info "Trying to install lsd ...\n"
		install_pkg_if_not_found cargo
		install_pkg_if_not_found rustc
		cargo install lsd
	fi
}

bootstrap_macos() {
	print_title "Executing bootstrap process for macOS ...\n"
	bootstrap_macports
	uninstall_fish
}

bootstrap_os() {
	print_info "Detecting OS ... "

	declare -A SUPPORTED_FAMILIES
	SUPPORTED_FAMILIES[debian]="Debian"
	SUPPORTED_FAMILIES[fedora]="Fedora"
	SUPPORTED_FAMILIES[darwin]="macOS"
	SUPPORTED_FAMILIES[ubuntu]="Ubuntu"

	declare -A SUPPORTED_VERSIONS
	SUPPORTED_VERSIONS[debian]="11"
	SUPPORTED_VERSIONS[fedora]="37"
	SUPPORTED_VERSIONS[darwin]="10.15"
	SUPPORTED_VERSIONS[ubuntu]="22.04"

	OS_FAMILY=`detect_os_family`
	OS_DISTRO=`detect_os_distro`
	if [ ! -z "${OS_DISTRO}" ]; then
		OS_LABEL="$OS_DISTRO"
	else
		OS_LABEL="$OS_FAMILY"
	fi
	OS_NAME="${SUPPORTED_FAMILIES[$OS_LABEL]}"
	OS_VERSION=`detect_os_version`

	print_success "${OS_NAME} ${OS_VERSION}\n"

	declare -A HANDLERS
	HANDLERS[debian]=bootstrap_debian
	HANDLERS[debian:11]=bootstrap_debian_11
	HANDLERS[debian:12]=bootstrap_debian_12
	HANDLERS[fedora]=bootstrap_fedora
	HANDLERS[fedora:37]=bootstrap_fedora
	HANDLERS[darwin]=bootstrap_macos
	HANDLERS[darwin:10.15]=bootstrap_macos
	HANDLERS[ubuntu]=bootstrap_ubuntu
	HANDLERS[ubuntu:22.04]=bootstrap_ubuntu

	BOOTSTRAP_HANDLER=${HANDLERS[$OS_LABEL:$OS_VERSION]}
	if [ -z "${BOOTSTRAP_HANDLER}" ]; then
		print_warning "${OS_NAME} ${OS_VERSION} is not officially supported and hasn't been tested.\n"
		print_caution "If you're lucky, things might still work ... but there's no guarantee.\n"
		print_caution "If you're unlucky, you might break your system.\n"
		read -p "Do you want to try nonetheless? [y/n] " yn
		case $yn in
			[yY])
				BOOTSTRAP_HANDLER=${HANDLERS[$OS_LABEL]}
				;;
			*)
				print_failure "Exiting ...\n"
				exit
				;;
		esac
	fi
	${BOOTSTRAP_HANDLER}
	echo
}

detect_fish_version() {
	fish --version | awk '{print($3)}'
}

case `detect_os_family` in
	"darwin")
		;;
	"linux")
		declare -A REQUIRES_ROOT
		REQUIRES_ROOT=(
			["/usr/share/fonts"]=1
			["/usr/local/share/fonts"]=1
			["${HOME}/.local/share/fonts"]=0
		)
		;;
esac

# Prompt to install Nerd Fonts
prompt_install_nerd_fonts() {
	read -p "Install Nerd Fonts? [y/n] " yn
	case $yn in
		[yY])
			OPTION_INDEX=""
			while [ "$OPTION_INDEX" == "" ]; do
				echo "Where do you want to install the fonts?"
				N=0
				FONT_DIRS=()
				for FONT_DIR in "${!REQUIRES_ROOT[@]}"; do
					N=$(($N+1))
					FONT_DIRS+=($FONT_DIR)
					if [ ${REQUIRES_ROOT[$FONT_DIR]} -eq 0 ]; then
						SCOPE="(current user only)"
					else
						SCOPE="(all users, requires root)"
					fi
					echo " ${N}) ${FONT_DIR} ${SCOPE}"
				done
				read -p "Enter an option: " OPTION_NUMBER
				if [ "$OPTION_NUMBER" -lt 1 ] || [ "$OPTION_NUMBER" -gt "$N" ]; then
					print_failure "Invalid answer: $OPTION_NUMBER\n"
					OPTION_INDEX=""
				else
					OPTION_INDEX=$(($OPTION_NUMBER))
				fi
			done
			FONTS_DIR=${FONT_DIRS[$(($OPTION_INDEX-1))]}
			echo "Will install Nerds Fonts to $FONTS_DIR"
			install_nerd_fonts "v2.3.3" "$FONTS_DIR" \
				JetBrainsMono \
				Meslo
			;;
		*)
			print_caution "Will not install Nerd Fonts.\n"
			echo
			;;
	esac
}

# Install the given Nerd Fonts
# install_nerd_fonts <version> <fonts_dir> <font> [<font> ...]
install_nerd_fonts() {
	print_title "Installing Nerd Fonts ...\n"
	RELEASE_TAG="${1}"
	FONTS_DIR="${2}"
	FONTS_LIST="${@:3}"
	DOWNLOAD_DIR="${SCRIPT_DIR}/fonts"
	mkdir -p ${DOWNLOAD_DIR}
	for FONT_NAME in ${FONTS_LIST}; do
		DEST_DIR="${FONTS_DIR}/nerd-fonts/${FONT_NAME}"
		if [ -e "${DEST_DIR}" ]; then
			print_caution "${FONT_NAME} is already installed at ${DEST_DIR}\n"
		else
			RELEASE_FILE="${FONT_NAME}.zip"
			RELEASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${RELEASE_TAG}/${RELEASE_FILE}"
			DOWNLOADED_FILE="${DOWNLOAD_DIR}/${RELEASE_FILE}"
			print_info "Downloading ${RELEASE_URL} ...\n"
			wget -c "${RELEASE_URL}" -O "${DOWNLOADED_FILE}"
			if [ "$?" -ne 0 ]; then
				print_failure "Failed to download ${FONT_NAME}\n"
			else
				sudo_if_needed ${REQUIRES_ROOT[$FONTS_DIR]} \
					mkdir -p "${DEST_DIR}"
				print_info "Unpacking ${DOWNLOADED_FILE} ...\n"
				sudo_if_needed ${REQUIRES_ROOT[$FONTS_DIR]} \
					unzip "${DOWNLOADED_FILE}" '*.ttf' -d "${DEST_DIR}"
				rm -iv "${DOWNLOADED_FILE}"
				print_success "Installed ${FONT_NAME} -> ${DEST_DIR}\n"
			fi
		fi
	done
	echo
	print_title "Updating font cache ...\n"
	fc-cache -f "${FONTS_DIR}"
	echo
}

link_files() {
	SRC="${@:-1}"
	DST="${@:$#:$#}"
	for SRCPATH in $SRC; do
		OUTPUT=`ln -sv $SRCPATH $DST 2>&1`
		if [ $? -eq 0 ]; then
			print_success "${OUTPUT}\n"
		else
			print_caution "${OUTPUT}\n"
		fi
	done
}

link_fish_files() {
	print_title "Linking fish configuration files ...\n"
	FISH_CONFIG="${HOME}/.config/fish"
	mkdir -pv ${FISH_CONFIG}/{conf.d,functions}
	set +e
	link_files ${SCRIPT_DIR}/conf.d/*.fish ${FISH_CONFIG}/conf.d/
	link_files ${SCRIPT_DIR}/functions/*.fish ${FISH_CONFIG}/functions/
	link_files ${SCRIPT_DIR}/fish_* ${FISH_CONFIG}/
	set -e
	echo
}

ensure_fish_version() {
	EXPECTED_VERSION="${1}"
	INSTALLED_VERSION=`detect_fish_version`
	if [ "${INSTALLED_VERSION}" != "${EXPECTED_VERSION}" ]; then
		panic "expected fish version ${EXPECTED_VERSION}, got ${INSTALLED_VERSION} instead!"
	fi
}

install_fisher() {
	ensure_fish_version ${DESIRED_FISH_VERSION}
	FISH_SCRIPT="https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish"
	print_title "Installing fisher ...\n"
	echo "I need to fetch and run the script ${FISH_SCRIPT}"
	print_caution "I'm about to download a script from the internet and pipe it through fish!\n"
	print_warning "This can have serious security implications!\n"
	read -p "Would you like to proceed? [y/n] " yn
	case $yn in
		[yY])
			fish <<EOF
wget -q -O - ${FISH_SCRIPT} | source
fisher update
EOF
			echo
			print_tip "To start a fish session, run:\n"
			print_tip "    fish\n"
			print_tip "To configure the tide prompt, run:\n"
			print_tip "    tide configure\n"
			;;
		*)
			echo
			print_caution "Please install fisher manually:\n"
			print_caution "    fish\n"
			print_caution "    wget -q -O /tmp/fisher.fish ${FISH_SCRIPT}\n"
			print_caution "    less /tmp/fisher.fish # check script for malicious code\n"
			print_caution "    source /tmp/fisher.fish\n"
			print_caution "    fisher update\n"
			print_caution "Optionally:\n"
			print_caution "    tide configure\n"
			echo
			;;
	esac
}

check_prerrequisites() {
	print_title "Checking prerrequisites ...\n"
	install_pkg_if_not_found curl # fisher uses curl and we can't change this fact
	install_pkg_if_not_found wget # we prefer wget to be able to resume downloads
	install_pkg_if_not_found fish
	install_pkg_if_not_found fontconfig fc-cache
	install_pkg_if_not_found lsd
	install_pkg_if_not_found unzip
	case `detect_os_family` in
		"darwin")
			install_pkg_if_not_found realpath
			;;
		"linux")
			install_pkg_if_not_found coreutils realpath
			;;
	esac
	echo
}

bootstrap_os
check_prerrequisites

# realpath is installed in check_prerrequisites, so we can't compute SCRIPT_DIR
# earlier than this
SCRIPT_DIR=`dirname $(realpath "${BASH_SOURCE}")`

prompt_install_nerd_fonts
link_fish_files
install_fisher

print_tip "To set fish as your default shell, run:\n"
print_tip "    chsh -s `command -v fish`\n"
if ! command -v chsh &> /dev/null; then
	print_warning "chsh is not installed\n"
fi
echo

print_success "Done!\n"
