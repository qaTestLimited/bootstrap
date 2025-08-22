#!/bin/zsh

# Determine the directory where this script is located (used to prefix other scripts)
leatherman_home=$(dirname "$0")

# Display a header for the Leatherman tool
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m  Leatherman\n"

# Source the environment file if it exists, this will define the leatherman_githome variable (used to find the qaTestLimited repo folder)
if [[ -f ~/.leatherman ]]; then
    source ~/.leatherman
fi

# Check if the leatherman_githome environment variable is set and valid, if not, unset it to trigger a prompt to the user (see below)
if [[ -n "${leatherman_githome}" ]]; then
    if [[ ! -d "${leatherman_githome}" ]]; then
        echo "The leatherman_githome environment variable is set to a non-existent directory: ${leatherman_githome}"
        unset leatherman_githome
    fi
fi

# Check if the leatherman_account environment variable is set and valid, if not, unset it to trigger a prompt to the user (see below)
if [[ -n "${leatherman_account}" ]]; then
    if [[ ! -d "${leatherman_githome}/${leatherman_account}" ]]; then
        echo "The leatherman_account environment variable (${leatherman_account}) is set to a non-existent directory.  Full path: ${leatherman_githome}/${leatherman_account}"
        unset leatherman_account
    fi
fi

# Prompt the user to set leatherman_githome if it is not already set
if [[ -z "${leatherman_githome}" ]]; then
    read "leatherman_githome?Enter the path to your GitHub folder (default is ~/GitHub): " 
    if [[ -z "${leatherman_githome}" ]]; then
        leatherman_githome=~/GitHub
    fi
    # Save leatherman_githome to a persistent file for future use
    echo "export leatherman_githome=${leatherman_githome}" > ~/.leatherman
    echo "export leatherman_account=qaTestLimited" >> ~/.leatherman
    echo "export leatherman_accounts={qaTestLimited}" >> ~/.leatherman
    echo "export leatherman_repos='{\"qaTestLimited\":{\"production\":[\"leatherman\"]}}'"
    source ~/.leatherman
fi

mkdir -p ${leatherman_githome}

# Exit if the leatherman_githome directory does not exist
if [[ ! -d "${leatherman_githome}" ]]; then
	echo -e "\e[31mError: The leatherman_githome folder does not exist: \e[0m ${leatherman_githome}"
    exit 1
fi

echo "leatherman_account set to qaTestLimited"
leatherman_account="qaTestLimited"

mkdir -p ${leatherman_githome}/${leatherman_account}

# Exit if the leatherman_githome directory does not exist
if [[ ! -d "${leatherman_githome}/${leatherman_account}" ]]; then
	echo -e "\e[31mError: The leatherman_account folder does not exist.\e[0m Full path: ${leatherman_githome}/${leatherman_account}"
    exit 1
fi

# Check if the .repos file exists in leatherman_githome, this is an indication that the folder is set up correctly
if [[ ! -f "${leatherman_githome}/${leatherman_account}/.leatherman" ]]; then
	echo -e "\e[33mWarning: Your qaTest leatherman_githome folder is not setup correctly\e[0m"
    read "setup?Do you want to correct the setup of the qaTest leatherman_githome folder? (y/n): "
    if [[ "${setup}" == "y" ]]; then
        command="bootstrap"
    else
        echo "\e[31mError: qaTest leatherman_githome folder is not setup correctly.  Bootstrap process aborted.\e[0m"
        exit 1
    fi
fi

# Warn the user if the script has already been run
if [[ -f ${leatherman_githome}/.repos ]]; then
    echo -e "\n\e[1mWARNING:\e[0m Bootstrap has already been run. This script is typically only needed to install newer versions of tools or reauthenticate with GitHub."
    read "proceed?Do you want to proceed with reinstallation? (y/n): "
    if [[ "$proceed" != "y" ]]; then
        echo -e "\nOperation canceled by the user."
        exit 1
    fi
fi

# Create GitHub folder structure for development
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...creating GitHub folder structure\n"

mkdir -p ${leatherman_githome}
cd ${leatherman_githome} || { echo "Error: Failed to navigate to directory ${leatherman_githome}"; exit 1; }
mkdir -p development staging production

# Verify that the directories exist after the operation
for dir in development staging production; do
	if [[ ! -d "${leatherman_githome}/${dir}" ]]; then
		echo "Error: Directory '${leatherman_githome}/${dir}' does not exist after the operation"
		exit 1
	fi
done

# Install Xcode command line tools, brew, envchain, and other dependencies
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...installing Xcode command line tools\n"

# Uncomment the following line if Xcode tools are required
# xcode-select --install || { echo "Error: Failed to install Xcode command line tools"; exit 1; }

echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...installing brew\n"

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || { echo "Error: Failed to install Homebrew"; exit 1; }

if ! which brew &> /dev/null; then
    echo "Homebrew is not in the PATH. Attempting to add it..."
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        touch ~/.zprofile
        echo "$(/opt/homebrew/bin/brew shellenv)" >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        touch ~/.zprofile
        echo "$(/usr/local/bin shellenv)" >> ~/.zprofile
        eval "$(/usr/local/bin shellenv)"
    else
        echo "Error: Homebrew is not installed. Please install it first."
        exit 1
    fi
fi



echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...installing brew packages\n"

brew_packages=(
    envchain
    gh
    git
    mas
    pandoc
    coreutils
)

for package in "${brew_packages[@]}"; do
    if [[ $package == \#* ]]; then
        continue
    fi
    brew install "$package" || { echo "Error: Failed to install package $package"; exit 1; }
done


# Authenticate with GitHub CLI
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...authenticating to GitHub\n"

if ! gh auth status > /dev/null 2>&1; then
    gh auth login || { echo "Error: GitHub authentication failed"; exit 1; }
fi

gh auth status || { echo "Error: Failed to verify GitHub authentication"; exit 1; }
# Setup GitHub current user configuration (global)
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...setting global git user details\n"

git config --global user.email "$(gh api 'https://api.github.com/user' | jq -r .email)" || { echo "Error: Failed to set Git user email"; exit 1; }
git config --global user.name "$(gh api 'https://api.github.com/user' | jq -r .name)" || { echo "Error: Failed to set Git user name"; exit 1; }

# Clone leatherman for access to utility scripts (production version)
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...setting up local install of leatherman\n"

cd ${leatherman_githome}/production || { echo "Error: Failed to navigate to production directory"; exit 1; }
rm -f -r leatherman || { echo "Error: Failed to remove existing leatherman directory"; exit 1; }
gh repo clone https://github.com/qaTestLimited/leatherman.git -- -b main || { echo "Error: Failed to clone leatherman repository"; exit 1; }

# Delete/define aliases to zsh profile for leatherman scripts, force reload of zsh resource file
touch ~/.zshrc
sed -i '' '/alias q=/d' ~/.zshrc || { echo "Error: Failed to remove existing 'q' alias"; exit 1; }
echo "alias q='${leatherman_githome}/production/leatherman/leatherman.sh'" >> ~/.zshrc || { echo "Error: Failed to add 'q' alias"; exit 1; }
alias q="${leatherman_githome}/production/leatherman/leatherman.sh"
sed -i '' '/alias leatherman=/d' ~/.zshrc || { echo "Error: Failed to remove existing 'leatherman' alias"; exit 1; }
echo "alias leatherman='${leatherman_githome}/production/leatherman/leatherman.sh'" >> ~/.zshrc || { echo "Error: Failed to add 'leatherman' alias"; exit 1; }
alias leatherman="${leatherman_githome}/production/leatherman/leatherman.sh"

source ~/.zshrc || { echo "Error: Failed to reload zsh configuration"; exit 1; }

touch ${leatherman_githome}/.repos || { echo "Error: Failed to create .repos file"; exit 1; }
