#!/bin/bash
#----------------------------------------------------------------------------------------------------------------------------------------
# Copyright (c) Robin Walter. All rights reserved.
# Licensed under the MIT License. See https://github.com/robinwalterfit/devcontainers-features/blob/main/LICENSE for license information.
#----------------------------------------------------------------------------------------------------------------------------------------
#
# Docs: https://github.com/robinwalterfit/devcontainers-features/tree/main/src/zsh
# Maintainer: Robin Walter <hello@robinwalter.me>

OVERWRITE_DEFAULT_OH_MY_ZSH="${OVERWRITEDEFAULTOHMYZSH:-false}"

UPDATE_RC="true"
USERNAME=${USERNAME:-"automatic"}

set -e

# Clean up
rm -rf /var/lib/apt/lists/*

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u "${CURRENT_USER}" > /dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
    USERNAME=root
fi

apt_get_update() {
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

updaterc() {
    if [ "${UPDATE_RC}" = "true" ]; then
        echo "Updating /home/${USERNAME}/.zshrc..."
        if [ -f "/home/${USERNAME}/.zshrc" ] && [[ "$(cat /home/${USERNAME}/.zshrc)" != *"$1"* ]]; then
            echo -e "$1" >> /home/$USERNAME/.zshrc
        fi
    fi
}

# Ensure apt is in non-interactive to avoid prompts
export DEBIAN_FRONTEND=noninteractive

# Install dependencies
check_packages curl git locales nano zsh

# Don't setup zsh for root user
if [ "${USERNAME}" = "root" ]; then
    echo "This feature only supports images with non-root users!"
    exit 0
fi

if [ -d /home/$USERNAME/.oh-my-zsh ]; then
    if [ "${OVERWRITE_DEFAULT_OH_MY_ZSH}" = "true" ]; then
        echo "Removing existing Oh-My-ZSH configuration..."
        rm -r /home/$USERNAME/.oh-my-zsh
    else
        echo "Oh-My-ZSH is already installed for user ${USERNAME}."
        exit 0
    fi
fi

# Install Oh-My-ZSH
export ZSH=/home/$USERNAME/.oh-my-zsh
echo "Start the installation of Oh-My-ZSH..."
curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh | bash -s -- --unattended

# Install Powerlevel10k theme
echo "Clone Powerlevel10k theme..."
git clone https://github.com/romkatv/powerlevel10k.git /home/$USERNAME/.oh-my-zsh/custom/themes/powerlevel10k

# Install Oh-My-ZSH plugins
echo "Clone zsh-autosuggestions plugin..."
git clone https://github.com/zsh-users/zsh-autosuggestions.git /home/$USERNAME/.oh-my-zsh/custom/plugins/zsh-autosuggestions
echo "Clone zsh-syntax-highlighting plugin..."
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git /home/$USERNAME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# Copy ZSH configuration file to users home directory
echo "Copy custom .zshrc to /home/${USERNAME}..."
cp ./.zshrc /home/$USERNAME/.zshrc

# Copy Powerlevel10k configuration file to users home directory
echo "Copy custom .p10k.zsh to /home/${USERNAME}..."
cp ./.p10k.zsh /home/$USERNAME/.p10k.zsh

# Clean up
rm -rf /var/lib/apt/lists/*

# Ensure privs are correct
chown $USERNAME:$USERNAME /home/$USERNAME -R

echo "Done!"
