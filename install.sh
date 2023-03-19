#!/bin/bash

install_pkg_if_not_installed() {
	BIN_PATH=`which ${1}`
	if [ -z "${BIN_PATH}" ]; then
		echo "${1} not found. Trying to install ${1} ..."
		install_pkgs "${1}"
	else
		echo "${1} found at ${BIN_PATH}"
	fi
}

install_pkgs () {
	sudo dnf install "$*"
}

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
install_pkg_if_not_installed fish
install_pkg_if_not_installed lsd
install_pkg_if_not_installed wget
echo

install_nerd_fonts "v2.3.3" "${HOME}/.local/share/fonts" \
	JetBrainsMono \
	Meslo \
	RobotoMono \
	Ubuntu \
	UbuntuMono

link_fish_files

echo "Done!"
