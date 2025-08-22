#!/bin/zsh

# --- Functions ---
error_exit() {
    echo -e "\e[31mError: $1\e[0m"
    exit 1
}

create_dir() {
    mkdir -p "$1" || error_exit "Failed to create directory $1"
}

install_brew_package() {
    if ! brew list "$1" &>/dev/null; then
        brew install "$1" || error_exit "Failed to install package $1"
    fi
}

# --- Script Start ---
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m  Bootstrap\n"

# Source leatherman file if it exists
if [[ -f ~/.leatherman ]]; then
    source ~/.leatherman
fi

# Validate leatherman_githome
if [[ -n "${leatherman_githome}" ]]; then
    if [[ ! -d "${leatherman_githome}" ]]; then
        echo "The leatherman_githome environment variable is set to a non-existent directory: ${leatherman_githome}"
        unset leatherman_githome
    fi
fi

# Validate leatherman_account
if [[ -n "${leatherman_account}" ]]; then
    if [[ ! -d "${leatherman_githome}/${leatherman_account}" ]]; then
        echo "The leatherman_account environment variable (${leatherman_account}) was set to a non-existent account directory.  Full path: ${leatherman_githome}/${leatherman_account}"
        leatherman_account="qaTestLimited"
    fi
    echo "The leatherman_account environment variable was set to '${leatherman_account}'.  Bootstrap sets it to 'qaTestLimited'"
else
    echo "The leatherman_account environment variable was not set.  Bootstrap sets it to 'qaTestLimited'"
    leatherman_account="qaTestLimited"
fi

# Prompt for leatherman_githome if not set
if [[ -z "${leatherman_githome}" ]]; then
    read "leatherman_githome?Enter the path to your GitHub folder (default is ~/GitHub): "
    if [[ -z "${leatherman_githome}" ]]; then
        leatherman_githome="$HOME/GitHub"
    fi
    # Save leatherman_githome to persistent file
    {
        echo "export leatherman_githome='${leatherman_githome}'"
        echo "export leatherman_account='qaTestLimited'"
        echo "export leatherman_accounts='{qaTestLimited}'"
        echo "export leatherman_repos='{"qaTestLimited":{"production":["leatherman"]}}'"
    } > ~/.leatherman
    source ~/.leatherman
fi

create_dir "${leatherman_githome}"
if [[ ! -d "${leatherman_githome}" ]]; then
    error_exit "The leatherman_githome folder does not exist or could not be created: ${leatherman_githome}"
fi

create_dir "${leatherman_githome}/${leatherman_account}"
if [[ ! -d "${leatherman_githome}/${leatherman_account}" ]]; then
    error_exit "The leatherman_account folder does not exist or could not be created. Full path: ${leatherman_githome}/${leatherman_account}"
fi

# Warn if already run
if [[ -f "${leatherman_githome}/.repos" ]]; then
    echo -e "\n\e[1mWARNING:\e[0m Bootstrap has already been run. This script is typically only needed to install newer versions of tools or reauthenticate with GitHub."
    read "proceed?Do you want to proceed with reinstallation? (y/n): "
    if [[ "$proceed" != "y" ]]; then
        echo -e "\nOperation canceled by the user."
        exit 1
    fi
fi

# Create GitHub folder structure
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...creating GitHub folder structure\n"

cd "${leatherman_githome}/${leatherman_account}" || error_exit "Failed to navigate to directory ${leatherman_githome}/${leatherman_account}"
for dir in development staging production; do
    create_dir "$dir"
    if [[ ! -d "${leatherman_githome}/${leatherman_account}/${dir}" ]]; then
        error_exit "Directory '${leatherman_githome}/${leatherman_account}/${dir}' does not exist after or could not be created"
    fi
done

# Install Xcode command line tools, brew, envchain, and other dependencies
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...installing Xcode command line tools\n"
# Uncomment if needed
# xcode-select --install || error_exit "Failed to install Xcode command line tools"

echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...installing brew\n"

if ! command -v brew &>/dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || error_exit "Failed to install Homebrew"
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        touch ~/.zprofile
        echo "$(/opt/homebrew/bin/brew shellenv)" >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        touch ~/.zprofile
        echo "$(/usr/local/bin/brew shellenv)" >> ~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
    else
        error_exit "Homebrew is not installed or could not be installed."
    fi
fi

echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...installing brew packages\n"

brew_packages=(envchain gh git mas pandoc coreutils)
for package in "${brew_packages[@]}"; do
    install_brew_package "$package"
done

# Authenticate with GitHub CLI
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...authenticating to GitHub\n"
if ! gh auth status &>/dev/null; then
    gh auth login || error_exit "GitHub authentication failed"
fi
gh auth status || error_exit "Failed to verify GitHub authentication"

# Setup GitHub current user configuration (global)
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...setting global git user details\n"
user_email="$(gh api 'https://api.github.com/user' | jq -r .email)"
user_name="$(gh api 'https://api.github.com/user' | jq -r .name)"
if [[ -z "$user_email" || -z "$user_name" ]]; then
    echo "Warning: GitHub user email or name is empty. Please set them manually with git config --global."
else
    git config --global user.email "$user_email" || error_exit "Failed to set Git user email"
    git config --global user.name "$user_name" || error_exit "Failed to set Git user name"
fi

# Clone leatherman for access to utility scripts (production version)
echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...setting up local install of leatherman\n"
cd "${leatherman_githome}/${leatherman_account}/production" || error_exit "Failed to navigate to production directory"
if [[ -d leatherman ]]; then
    rm -rf leatherman || error_exit "Failed to remove existing leatherman directory"
fi
gh repo clone qaTestLimited/leatherman -- -b main || error_exit "Failed to clone leatherman repository"

# Update aliases in zshrc
touch ~/.zshrc
sed -i '' '/alias q=/d' ~/.zshrc || error_exit "Failed to remove existing 'q' alias"
echo "alias q='${leatherman_githome}/${leatherman_account}/production/leatherman/leatherman.sh'" >> ~/.zshrc || error_exit "Failed to add 'q' alias"
alias q="${leatherman_githome}/${leatherman_account}/production/leatherman/leatherman.sh"
sed -i '' '/alias leatherman=/d' ~/.zshrc || error_exit "Failed to remove existing 'leatherman' alias"
echo "alias leatherman='${leatherman_githome}/${leatherman_account}/production/leatherman/leatherman.sh'" >> ~/.zshrc || error_exit "Failed to add 'leatherman' alias"
alias leatherman="${leatherman_githome}/${leatherman_account}/production/leatherman/leatherman.sh"

source ~/.zshrc || error_exit "Failed to reload zsh configuration"

echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m DONE"
echo -e "\e[1m\e[31mNote:\e[0m Restart your shell or run 'source ~/.zshrc' to apply changes."