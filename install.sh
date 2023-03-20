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
		echo "Updating apt database ..."
		run_privileged apt-get update
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
	BIN_PATH=`command -v "${BIN_NAME}"` # https://stackoverflow.com/a/677212
	if [ -z "${BIN_PATH}" ]; then
		echo "${PKG_NAME}: ${BIN_NAME} not found. Trying to install ${PKG_NAME} ..."
		install_pkgs "${PKG_NAME}"
		if [ $? -ne 0 ]; then
			panic "Failed to install package: ${PKG_NAME}"
		fi
	else
		echo "${PKG_NAME}: ${BIN_NAME} found at ${BIN_PATH}"
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

# Get the installation path for fonts depending on whether the user is root or not
get_fonts_dir() {
	if [ `id -u` -eq 0 ]; then
		echo "/usr/local/share/fonts"
	else
		echo "${HOME}/.local/share/fonts"
	fi
}

# Install the given Nerd Fonts
# install_nerd_fonts <font> [<font> ...]
install_nerd_fonts() {
	echo "Installing Nerd Fonts ..."
	RELEASE_TAG="${1}"
	FONTS_LIST="${@:2}"
	FONTS_DIR=`get_fonts_dir`
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
				mkdir -p "${DEST_DIR}"
				echo "Unpacking ${DOWNLOADED_FILE} ..."
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
	# TODO: ask before running script from the internet
	fish <<EOF
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
fisher update
EOF
	echo "Installation finished!"
	echo "Run 'fish' and then 'tide configure'"
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

install_nerd_fonts "v2.3.3" \
	JetBrainsMono \
	Meslo

link_fish_files

install_fisher

echo "To set fish as your default shell, run: chsh -s `command -v fish`"

echo "Done!"
