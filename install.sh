#!/bin/bash
SCRIPT_DIR=`dirname "${BASH_SOURCE}"`
ln -sv ${SCRIPT_DIR}/conf.d/*.fish ${HOME}/.config/fish/conf.d/
