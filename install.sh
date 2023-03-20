#!/bin/bash

# Print error and exit
panic() {
	echo "$*" >&2
	exit 1
}

# Run command as privileged (root) user
# run_privileged <cmd> [<arg> ...]
run_privileged() {
	if [ `id -u` -eq 0 ]; then
		$*
	else
		if [ ! -z `command -v sudo` ]; then
			sudo $*
		elif [ ! -z `command -v doas` ]; then
			doas $*
		else
			panic "Unable to run command as root: no doas, sudo have been found"
		fi
	fi
}

# Bootstrap package manager
bootstrap_pkg() {
	if [ ! -z `command -v apt-get` ]; then
		read -p "Update apt database? [y/n] " yn
		case $yn in
			[yY])
				echo "Updating apt database ..."
				run_privileged apt-get update
				;;
			*)
				echo "Will not update apt database"
		esac
		echo
	fi
}

# Install a package if the given executable isn't found
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
			panic "Failed to install package: ${PKG_NAME}"
		fi
	else
		echo "${BIN_PATH}"
	fi
}

# Install packages
# install_pkgs <pkg> [<pkg> ...]
install_pkgs () {
	if [ ! -z `command -v apt-get` ]; then
		run_privileged apt-get install "$*"
	elif [ ! -z `command -v dnf` ]; then
		run_privileged dnf install "$*"
	else
		panic "Unknown Linux distro: could not find a known package manager"
	fi
}

declare -A REQUIRES_ROOT
REQUIRES_ROOT=(
	["/usr/share/fonts"]=1
	["/usr/local/share/fonts"]=1
	["${HOME}/.local/share/fonts"]=0
)

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
				echo Answer: $OPTION_NUMBER
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
	TMP_DIR=`mktemp -d`
	for FONT_NAME in ${FONTS_LIST}; do
		DEST_DIR="${FONTS_DIR}/nerd-fonts/${FONT_NAME}"
		if [ -e "${DEST_DIR}" ]; then
			echo "${FONT_NAME} is already installed at ${DEST_DIR}"
		else
			RELEASE_FILE="${FONT_NAME}.zip"
			RELEASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${RELEASE_TAG}/${RELEASE_FILE}"
			DOWNLOADED_FILE="${TMP_DIR}/${RELEASE_FILE}"
			echo "Downloading ${RELEASE_URL} ..."
			curl -L "${RELEASE_URL}" -o "${DOWNLOADED_FILE}"
			if [ "$?" -ne 0 ]; then
				echo "Failed to download ${FONT_NAME}"
			else
				sudo_if_needed ${REQUIRES_ROOT[$FONTS_DIR]} \
					mkdir -p "${DEST_DIR}"
				echo "Unpacking ${DOWNLOADED_FILE} ..."
				sudo_if_needed ${REQUIRES_ROOT[$FONTS_DIR]} \
					unzip -q "${DOWNLOADED_FILE}" '*.ttf' -d "${DEST_DIR}"
				rm "${DOWNLOADED_FILE}"
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
	mkdir -p "${FISH_CONFIG}"
	ln -sv ${SCRIPT_DIR}/conf.d/*.fish ${FISH_CONFIG}/conf.d/
	ln -sv ${SCRIPT_DIR}/functions/*.fish ${FISH_CONFIG}/functions/
	ln -sv ${SCRIPT_DIR}/fish_* ${FISH_CONFIG}/
	echo
}

check_version() {
	BIN_NAME="${1}"
	EXPECTED_VERSION="${2}"
	VERSION=`${BIN_NAME} --version | awk '{print($3)}'` # FIXME: awk expression will only work with fish
	if [ "${VERSION}" != "${EXPECTED_VERSION}" ]; then
		panic "Error: expected ${BIN_NAME} version ${EXPECTED_VERSION}, got ${VERSION} instead!"
	fi
}

install_fisher() {
	check_version fish 3.6.0
	FISH_SCRIPT="https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish"
	echo "Installing fisher ..."
	echo "I need to fetch and run the script ${FISH_SCRIPT}"
	echo "I'm about to download a script from the internet and pipe it through fish!"
	echo "This can have serious security implications!"
	read -p "Would you like to proceed? [y/n] " yn
	case $yn in
		[yY])
			fish <<EOF
curl -sL ${FISH_SCRIPT} | source
fisher update
EOF
			echo "Installation finished!"
			echo
			echo "To start a fish session, run: fish"
			echo "To configure the tide prompt, run: tide configure"
			;;
		*)
			echo "Please install fisher manually."
			;;
	esac
}

SCRIPT_DIR=`readlink -f $(dirname "${BASH_SOURCE}")`

bootstrap_pkg

echo "Checking prerrequisites ..."
install_pkg_if_not_found curl
install_pkg_if_not_found fish
install_pkg_if_not_found fontconfig fc-cache
install_pkg_if_not_found lsd
install_pkg_if_not_found unzip
echo

prompt_install_nerd_fonts

link_fish_files

install_fisher

echo "To set fish as your default shell, run: chsh -s `command -v fish`"

echo
echo "Done!"
