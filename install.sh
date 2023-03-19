#!/bin/bash

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
	else
		echo "${PKG_NAME}: ${BIN_NAME} found at ${BIN_PATH}"
	fi
}

install_pkgs () {
	# TODO: differentiate OS (Fedora, Ubuntu, etc.)
	sudo dnf install "$*"
}

get_fonts_dir() {
	USER=`whoami`
	if [ "$USER" == "root" ]; then
		echo "/usr/local/share/fonts"
	else
		echo "${HOME}/.local/share/fonts"
	fi
}

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
			wget -q "${RELEASE_URL}" -O "${DOWNLOADED_FILE}"
			if [ "$?" -ne 0 ]; then
				echo "Failed to download ${FONT_NAME}"
			else
				mkdir -p "${DEST_DIR}"
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
	ln -sv ${SCRIPT_DIR}/conf.d/*.fish ${HOME}/.config/fish/conf.d/
	ln -sv ${SCRIPT_DIR}/functions/*.fish ${HOME}/.config/fish/functions/
	ln -sv ${SCRIPT_DIR}/fish_* ${HOME}/.config/fish/
	echo
}

SCRIPT_DIR=`readlink -f $(dirname "${BASH_SOURCE}")`

echo "Checking prerrequisites ..."
install_pkg_if_not_found fish
install_pkg_if_not_found fontconfig fc-cache
install_pkg_if_not_found lsd
install_pkg_if_not_found unzip
install_pkg_if_not_found wget
echo

install_nerd_fonts "v2.3.3" \
	JetBrainsMono \
	Meslo \
	RobotoMono \
	Ubuntu \
	UbuntuMono

link_fish_files

echo "Done!"
