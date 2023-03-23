#!/bin/bash

set -e

DESIRED_FISH_VERSION="3.6.0"

NOCOLOR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LGRAY='\033[0;37m'
DGRAY='\033[1;30m'
LTRED='\033[1;31m'
LGREEN='\033[1;32m'
YELLOW='\033[1;33m'
LBLUE='\033[1;34m'
LPURPLE='\033[1;35m'
LCYAN='\033[1;36m'
WHITE='\033[1;37m'

print_regular() {
	echo -ne "$*"
}

print_info() {
	echo -ne "${BLUE}$*${NOCOLOR}"
}

print_title() {
	echo -ne "${LBLUE}$*${NOCOLOR}"
}

print_success() {
	echo -ne "${GREEN}$*${NOCOLOR}"
}

print_caution() {
	echo -ne "${YELLOW}$*${NOCOLOR}"
}

print_warning() {
	print_caution "WARNING: $*"
}

print_failure() {
	echo -ne "${RED}$*${NOCOLOR}"
}

print_error() {
	print_failure "ERROR: $*" >&2
}

# Print error and exit
panic() {
	print_failure "FATAL: $*\n"
	exit 1
}

# Run command as privileged (root) user
# run_privileged <cmd> [<arg> ...]
run_privileged() {
	if [ `id -u` -eq 0 ]; then
		$*
	else
		if command -v doas &> /dev/null; then
			doas $*
		elif command -v please &> /dev/null; then
			please $*
		elif command -v sudo &> /dev/null; then
			sudo $*
		else
			panic "failed to run as root: could not find any of: doas, please, sudo"
		fi
	fi
}

do_nothing() {
	echo > /dev/null
}

uninstall_pkgs() {
	if command -v apt-get &> /dev/null; then
		run_privileged apt-get remove -y $*
	elif command -v dnf &> /dev/null; then
		run_privileged dnf remove -y $*
	elif command -v port &> /dev/null; then
		run_privileged port -v uninstall $*
	else
		panic "could not find a known package manager"
	fi
}

uninstall_fish() {
	if command -v fish &> /dev/null; then
		INSTALLED_VERSION=`get_version fish`
		if [ "${INSTALLED_VERSION}" != "${DESIRED_FISH_VERSION}" ]; then
			uninstall_pkgs fish
		fi
	fi
}

bootstrap_apt() {
	read -p "Update apt database? [y/n] " yn
	case $yn in
		[yY])
			print_info "Updating apt database ...\n"
			run_privileged apt-get update
			;;
		*)
			print_caution "Will not update apt database\n"
	esac
}

bootstrap_debian() {
	bootstrap_apt
	# Uninstall fish if it's already installed
	uninstall_fish
	# Add PPA to install latest fish version
	install_pkg_if_not_found curl
	install_pkg_if_not_found gpg
	echo 'deb http://download.opensuse.org/repositories/shells:/fish:/release:/3/Debian_11/ /' | run_privileged tee /etc/apt/sources.list.d/shells:fish:release:3.list
	curl -fsSL https://download.opensuse.org/repositories/shells:fish:release:3/Debian_11/Release.key | gpg --dearmor | run_privileged tee /etc/apt/trusted.gpg.d/shells_fish_release_3.gpg > /dev/null
	# Install lsd using cargo
	install_pkgs cargo rustc
	cargo install lsd --version 0.18.0 # last crate version compatible with Debian's outdated cargo version
	export PATH="$HOME/.cargo/bin:$PATH"
}

bootstrap_ubuntu() {
	bootstrap_apt
	# Uninstall fish if it's already installed
	uninstall_fish
	# Add PPA to install latest fish version
	install_pkgs software-properties-common
	run_privileged apt-add-repository ppa:fish-shell/release-3
	run_privileged apt-get update
	# Install lsd using cargo
	install_pkgs cargo rustc
	cargo install lsd
	export PATH="$HOME/.cargo/bin:$PATH"
}

bootstrap_macports() {
	read -p "Update port database? [y/n] " yn
	case $yn in
		[yY])
			print_info "Updating port database ...\n"
			run_privileged port -v selfupdate
			;;
		*)
			print_caution "Will not update port database\n"
	esac
}

bootstrap_macos() {
	bootstrap_macports
	uninstall_fish
}

bootstrap_os() {
	SUPPORTED_PLATFORMS=(
		"Debian 11"
		"Fedora 37"
		"macOS 10+"
		"Ubuntu 22.04"
	)
	HANDLERS=(
		bootstrap_debian
		do_nothing
		bootstrap_macos
		bootstrap_ubuntu
	)
	OPTION_INDEX=""
	while [ "$OPTION_INDEX" == "" ]; do
		echo "What operating system / distribution are you using?"
		N=0
		for PLATFORM in "${SUPPORTED_PLATFORMS[@]}"; do
			N=$(($N+1))
			echo " ${N}) ${PLATFORM}"
		done
		read -p "Enter an option: " OPTION_NUMBER
		if [ "$OPTION_NUMBER" -lt 1 ] || [ "$OPTION_NUMBER" -gt "$N" ]; then
			print_failure "Invalid answer: $OPTION_NUMBER\n"
			OPTION_INDEX=""
		else
			OPTION_INDEX=$(($OPTION_NUMBER-1))
		fi
	done
	PLATFORM=${SUPPORTED_PLATFORMS[$OPTION_INDEX]}
	print_title "Executing bootstrap process for ${PLATFORM} ...\n"
	${HANDLERS[$OPTION_INDEX]}
	echo
}

# Install package <pkg> if the executable <exe> cannot be found in the PATH
# install_pkg_if_not_found <pkg> <exe>
install_pkg_if_not_found() {
	PKG_NAME="${1}"
	BIN_NAME="${2}"
	if [ -z "${BIN_NAME}" ]; then
		BIN_NAME="${PKG_NAME}"
	fi
	print_regular "Checking ${PKG_NAME} ... "
	if ! command -v "${BIN_NAME}" &> /dev/null; then
		print_failure "${BIN_NAME} not found\n"
		print_info "Trying to install ${PKG_NAME} ...\n"
		install_pkgs "${PKG_NAME}"
		if [ $? -ne 0 ]; then
			panic "failed to install package: ${PKG_NAME}"
		fi
	else
		BIN_PATH=`command -v "${BIN_NAME}"`
		print_success "${BIN_PATH}\n"
	fi
}

# Install packages
# install_pkgs <pkg> [<pkg> ...]
install_pkgs () {
	if command -v apt-get &> /dev/null; then
		run_privileged apt-get install -y $*
	elif command -v dnf &> /dev/null; then
		run_privileged dnf install -y $*
	elif command -v port &> /dev/null; then
		run_privileged port -v install $*
	else
		panic "could not find a known package manager"
	fi
}

case `uname` in
	"Darwin")
		;;
	"Linux")
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

sudo_if_needed() {
	SUDO_NEEDED="${1}"
	COMMAND="${@:2}"
	if [ $SUDO_NEEDED -eq 1 ]; then
		run_privileged ${COMMAND}
	else
		${COMMAND}
	fi
}

link_fish_files() {
	print_title "Linking fish configuration files ...\n"
	FISH_CONFIG="${HOME}/.config/fish"
	mkdir -pv ${FISH_CONFIG}/{conf.d,functions}
	set +e
	ln -sv ${SCRIPT_DIR}/conf.d/*.fish ${FISH_CONFIG}/conf.d/
	ln -sv ${SCRIPT_DIR}/functions/*.fish ${FISH_CONFIG}/functions/
	ln -sv ${SCRIPT_DIR}/fish_* ${FISH_CONFIG}/
	set -e
	echo
}

get_version() {
	BIN_NAME="${1}"
	EXPECTED_VERSION="${2}"
	${BIN_NAME} --version | awk '{print($3)}' # FIXME: awk expression will only work with fish
}

ensure_version() {
	BIN_NAME="${1}"
	EXPECTED_VERSION="${2}"
	VERSION=`get_version ${BIN_NAME}`
	if [ "${VERSION}" != "${EXPECTED_VERSION}" ]; then
		panic "expected ${BIN_NAME} version ${EXPECTED_VERSION}, got ${VERSION} instead!"
	fi
}

install_fisher() {
	ensure_version fish ${DESIRED_FISH_VERSION}
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
			print_success "Installation finished!\n"
			echo
			print_caution "To start a fish session, run: fish\n"
			print_caution "To configure the tide prompt, run: tide configure\n"
			;;
		*)
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
	case `uname` in
		"Darwin")
			install_pkg_if_not_found realpath
			;;
		"Linux")
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

print_caution "To set fish as your default shell, run: chsh -s `command -v fish`\n"
echo
print_success "Done!\n"
