#!/bin/zsh

# Determine the directory where this script is located (used to prefix other scripts)
leathermanhome=$(dirname "$0")

# Display a header for the Leatherman tool
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m  Leatherman\n"

# Source the environment file if it exists, this will define the githome variable (used to find the qaTestLimited repo folder)
if [[ -f ~/.leatherman_env ]]; then
    source ~/.leatherman_env
fi

# Parse the first command-line argument as the command, converting it to lowercase
if [[ $# -gt 0 ]]; then
    command=${1:l}; shift
else
    command=""
fi

# Check if the githome environment variable is set and valid, if not, unset it to trigger a prompt to the user (see below)
if [[ -n "${githome}" ]]; then
    if [[ ! -d "${githome}" ]]; then
        echo "The githome environment variable is set to a non-existent directory: ${githome}"
        unset githome
    fi
fi

# Prompt the user to set githome if it is not already set
if [[ -z "${githome}" ]]; then
    read "githome?Enter the path to your qaTestLimited GitHub folder (default is ~/GitHub/qaTestLimited): " 
    if [[ -z "${githome}" ]]; then
        githome=~/GitHub/qaTestLimited
    fi
    # Save githome to a persistent file for future use
    echo "export githome=${githome}" > ~/.leatherman_env
    source ~/.leatherman_env
fi

# Exit if the githome directory does not exist
if [[ ! -d "${githome}" ]]; then
	echo -e "\e[31mError: The githome folder does not exist: \e[0m ${githome}"
    exit 1
fi

# Check if the .repos file exists in githome, this is an indication that the folder is set up correctly
if [[ ! -f "${githome}/.repos" ]]; then
	echo -e "\e[33mWarning: Your qaTest githome folder is not setup correctly\e[0m"
    read "setup?Do you want to correct the setup of the qaTest githome folder? (y/n): "
    if [[ "${setup}" == "y" ]]; then
        command="bootstrap"
    else
        echo "\e[31mError: qaTest githome folder is not setup correctly.\e[0m"
        exit 1
    fi
fi

# Warn the user if the script has already been run
if [[ -f ${leathermanhome}/.repos ]]; then
    echo -e "\n\e[1mWARNING:\e[0m Bootstrap has already been run. This script is typically only needed to install newer versions of tools or reauthenticate with GitHub."
    read "proceed?Do you want to proceed with reinstallation? (y/n): "
    if [[ "$proceed" != "y" ]]; then
        echo -e "\nOperation canceled by the user."
        exit 1
    fi
fi

# Create GitHub folder structure for development
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...creating GitHub folder structure\n"

mkdir -p ${githome}
cd ${githome} || { echo "Error: Failed to navigate to directory ${githome}"; exit 1; }
mkdir -p development staging production

# Verify that the directories exist after the operation
for dir in development staging production; do
	if [[ ! -d "${githome}/${dir}" ]]; then
		echo "Error: Directory '${githome}/${dir}' does not exist after the operation"
		exit 1
	fi
done

# Install Xcode command line tools, brew, envchain, and other dependencies
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...installing Xcode command line tools\n"

# Uncomment the following line if Xcode tools are required
# xcode-select --install || { echo "Error: Failed to install Xcode command line tools"; exit 1; }

echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...installing brew\n"

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || { echo "Error: Failed to install Homebrew"; exit 1; }

echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...installing brew packages\n"

touch ~/myPackages.cfg || { echo "Error: Failed to create ~/myPackages.cfg"; exit 1; }

for file in "${installdir}/leathermanInstallPackages.cfg" ~/myPackages.cfg
do
    if [[ -f "$file" ]]; then
        while IFS=' ' read -r package _
        do
            if [[ $package == \#* ]]; then
                continue
            fi
            brew install $package || { echo "Error: Failed to install package $package"; exit 1; }
        done < "$file"
    fi
done

# Authenticate with GitHub CLI
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...authenticating to GitHub\n"

gh auth login || { echo "Error: GitHub authentication failed"; exit 1; }
gh auth status || { echo "Error: Failed to verify GitHub authentication"; exit 1; }

# Setup GitHub current user configuration (global)
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...setting global git user details\n"

git config --global user.email "$(gh api 'https://api.github.com/user' | jq -r .email)" || { echo "Error: Failed to set Git user email"; exit 1; }
git config --global user.name "$(gh api 'https://api.github.com/user' | jq -r .name)" || { echo "Error: Failed to set Git user name"; exit 1; }

# Clone leatherman for access to utility scripts (production version)
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...setting up local install of leatherman\n"

cd ${githome}/production || { echo "Error: Failed to navigate to production directory"; exit 1; }
rm -f -r leatherman || { echo "Error: Failed to remove existing leatherman directory"; exit 1; }
gh repo clone https://github.com/qaTestLimited/leatherman.git -- -b main || { echo "Error: Failed to clone leatherman repository"; exit 1; }

# Delete/define aliases to zsh profile for leatherman scripts, force reload of zsh resource file
sed -i '' '/alias q=/d' ~/.zshrc || { echo "Error: Failed to remove existing 'q' alias"; exit 1; }
echo "alias q='${githome}/production/leatherman/leatherman.sh'" >> ~/.zshrc || { echo "Error: Failed to add 'q' alias"; exit 1; }
sed -i '' '/alias leatherman=/d' ~/.zshrc || { echo "Error: Failed to remove existing 'leatherman' alias"; exit 1; }
echo "alias leatherman='${githome}/production/leatherman/leatherman.sh'" >> ~/.zshrc || { echo "Error: Failed to add 'leatherman' alias"; exit 1; }
source ~/.zshrc || { echo "Error: Failed to reload zsh configuration"; exit 1; }

touch ${githome}/.repos || { echo "Error: Failed to create .repos file"; exit 1; }
