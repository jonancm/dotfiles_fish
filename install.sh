#!/bin/bash
SCRIPT_DIR=`readlink -f $(dirname "${BASH_SOURCE}")`
ln -sv ${SCRIPT_DIR}/conf.d/*.fish ${HOME}/.config/fish/conf.d/
ln -sv ${SCRIPT_DIR}/fish_* ${HOME}/.config/fish/
