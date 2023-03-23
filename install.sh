#!/bin/bash

DESIRED_FISH_VERSION="3.6.0"

# Print error and exit
panic() {
	echo "Error: $*" >&2
	exit 1
}

# Run command as privileged (root) user
# run_privileged <cmd> [<arg> ...]
run_privileged() {
	if [ `id -u` -eq 0 ]; then
		$*
	else
		if [ ! -z `command -v doas` ]; then
			doas $*
		elif [ ! -z `command -v please` ]; then
			please $*
		elif [ ! -z `command -v sudo` ]; then
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
	if [ ! -z `command -v apt-get` ]; then
		run_privileged apt-get remove $*
	elif [ ! -z `command -v dnf` ]; then
		run_privileged dnf remove $*
	elif [ ! -z `command -v port` ]; then
		run_privileged port -v uninstall $*
	else
		panic "could not find a known package manager"
	fi
}

uninstall_fish() {
	if [ ! -z `command -v fish` ]; then
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
			echo "Updating apt database ..."
			run_privileged apt-get update
			;;
		*)
			echo "Will not update apt database"
	esac
}

bootstrap_debian() {
	bootstrap_apt
	# Uninstall fish if it's already installed
	uninstall_fish
	# Add PPA to install latest fish version
	run_privileged apt-get install curl gpg
	echo 'deb http://download.opensuse.org/repositories/shells:/fish:/release:/3/Debian_11/ /' | run_privileged tee /etc/apt/sources.list.d/shells:fish:release:3.list
	curl -fsSL https://download.opensuse.org/repositories/shells:fish:release:3/Debian_11/Release.key | gpg --dearmor | run_privileged tee /etc/apt/trusted.gpg.d/shells_fish_release_3.gpg > /dev/null
	# Install lsd using cargo
	run_privileged apt-get install cargo rustc
	cargo install lsd --version 0.18.0 # last crate version compatible with Debian's outdated cargo version
	export PATH="$HOME/.cargo/bin:$PATH"
}

bootstrap_ubuntu() {
	bootstrap_apt
	# Uninstall fish if it's already installed
	uninstall_fish
	# Add PPA to install latest fish version
	run_privileged apt-get install software-properties-common
	run_privileged apt-add-repository ppa:fish-shell/release-3
	run_privileged apt-get update
	# Install lsd using cargo
	run_privileged apt-get install cargo rustc
	cargo install lsd
	export PATH="$HOME/.cargo/bin:$PATH"
}

bootstrap_macports() {
	read -p "Update port database? [y/n] " yn
	case $yn in
		[yY])
			echo "Updating port database ..."
			run_privileged port -v selfupdate
			;;
		*)
			echo "Will not update port database"
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
			echo "Invalid answer: $OPTION_NUMBER"
			OPTION_INDEX=""
		else
			OPTION_INDEX=$(($OPTION_NUMBER-1))
		fi
	done
	PLATFORM=${SUPPORTED_PLATFORMS[$OPTION_INDEX]}
	echo "Executing bootstrap process for ${PLATFORM} ..."
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
	echo -n "Checking ${PKG_NAME} ... "
	BIN_PATH=`command -v "${BIN_NAME}"` # https://stackoverflow.com/a/677212
	if [ -z "${BIN_PATH}" ]; then
		echo "${BIN_NAME} not found"
		echo "Trying to install ${PKG_NAME} ..."
		install_pkgs "${PKG_NAME}"
		if [ $? -ne 0 ]; then
			panic "failed to install package: ${PKG_NAME}"
		fi
	else
		echo "${BIN_PATH}"
	fi
}

# Install packages
# install_pkgs <pkg> [<pkg> ...]
install_pkgs () {
	if [ ! -z `command -v apt-get` ]; then
		run_privileged apt-get install $*
	elif [ ! -z `command -v dnf` ]; then
		run_privileged dnf install $*
	elif [ ! -z `command -v port` ]; then
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
					echo "Invalid answer: $OPTION_NUMBER"
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
			echo "Will not install Nerd Fonts."
			echo
			;;
	esac
}

# Install the given Nerd Fonts
# install_nerd_fonts <version> <fonts_dir> <font> [<font> ...]
install_nerd_fonts() {
	echo "Installing Nerd Fonts ..."
	RELEASE_TAG="${1}"
	FONTS_DIR="${2}"
	FONTS_LIST="${@:3}"
	for FONT_NAME in ${FONTS_LIST}; do
		DEST_DIR="${FONTS_DIR}/nerd-fonts/${FONT_NAME}"
		if [ -e "${DEST_DIR}" ]; then
			echo "${FONT_NAME} is already installed at ${DEST_DIR}"
		else
			RELEASE_FILE="${FONT_NAME}.zip"
			RELEASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${RELEASE_TAG}/${RELEASE_FILE}"
			DOWNLOADED_FILE="/tmp/${RELEASE_FILE}"
			echo "Downloading ${RELEASE_URL} ..."
			wget -c "${RELEASE_URL}" -O "${DOWNLOADED_FILE}"
			if [ "$?" -ne 0 ]; then
				echo "Failed to download ${FONT_NAME}"
			else
				sudo_if_needed ${REQUIRES_ROOT[$FONTS_DIR]} \
					mkdir -p "${DEST_DIR}"
				echo "Unpacking ${DOWNLOADED_FILE} ..."
				sudo_if_needed ${REQUIRES_ROOT[$FONTS_DIR]} \
					unzip "${DOWNLOADED_FILE}" '*.ttf' -d "${DEST_DIR}"
				rm -iv "${DOWNLOADED_FILE}"
				echo "Installed ${FONT_NAME} -> ${DEST_DIR}"
			fi
		fi
	done
	echo
	echo "Updating font cache ..."
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
	echo "Linking fish configuration files ..."
	FISH_CONFIG="${HOME}/.config/fish"
	mkdir -pv ${FISH_CONFIG}/{conf.d,functions}
	ln -sv ${SCRIPT_DIR}/conf.d/*.fish ${FISH_CONFIG}/conf.d/
	ln -sv ${SCRIPT_DIR}/functions/*.fish ${FISH_CONFIG}/functions/
	ln -sv ${SCRIPT_DIR}/fish_* ${FISH_CONFIG}/
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
	echo "Installing fisher ..."
	echo "I need to fetch and run the script ${FISH_SCRIPT}"
	echo "I'm about to download a script from the internet and pipe it through fish!"
	echo "This can have serious security implications!"
	read -p "Would you like to proceed? [y/n] " yn
	case $yn in
		[yY])
			fish <<EOF
wget -q -O - ${FISH_SCRIPT} | source
fisher update
EOF
			echo "Installation finished!"
			echo
			echo "To start a fish session, run: fish"
			echo "To configure the tide prompt, run: tide configure"
			;;
		*)
			echo "Please install fisher manually:"
			echo "    fish"
			echo "    wget -q -O - ${FISH_SCRIPT} | source"
			echo "    fisher update"
			echo "Optionally:"
			echo "    tide configure"
			echo
			;;
	esac
}

check_prerrequisites() {
	echo "Checking prerrequisites ..."
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
prompt_install_nerd_fonts
SCRIPT_DIR=`dirname $(realpath "${BASH_SOURCE}")`
link_fish_files
install_fisher
echo "To set fish as your default shell, run: chsh -s `command -v fish`"
echo
echo "Done!"
