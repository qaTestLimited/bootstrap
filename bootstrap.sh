#!/bin/zsh

# --- bootstrap functions ---
error_exit() {
    echo -e "\e[31mError: $1\e[0m"
    exit 1
}

require_command() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || error_exit "Required command '$cmd' is not installed or not in PATH"
}

create_dir() {
    mkdir -p "$1" || error_exit "Failed to create directory $1"
}

export LEATHERMAN_STATE_FILE="$HOME/.config/leatherman/state.json"

qLoadState() {
  if [[ -f "$LEATHERMAN_STATE_FILE" ]]; then
    export leatherman="$(cat "$LEATHERMAN_STATE_FILE")"
  else
    export leatherman='{}'
  fi
}

qSaveState() {
  mkdir -p "$(dirname "$LEATHERMAN_STATE_FILE")"
  printf '%s' "$leatherman" | jq -c . > "$LEATHERMAN_STATE_FILE"
}

qSetEnv() {
  local key_path="${1#.}"
  local val="$2"
  
  # Initialize if variable is unset
  : "${leatherman:={}}"

  # Handle JSON literals (booleans, arrays, objects) vs standard strings
  if echo "$val" | jq -e . >/dev/null 2>&1; then
    leatherman=$(printf '%s' "$leatherman" | jq --arg path "$key_path" --argjson v "$val" \
      'setpath($path | split("."); $v)')
  else
    leatherman=$(printf '%s' "$leatherman" | jq --arg path "$key_path" --arg v "$val" \
      'setpath($path | split("."); $v)')
  fi

  # Auto-persist state to disk on every change
  qSaveState
}

qGetEnv() {
  local key_path="${1#.}"
  
  if [[ -z "$key_path" ]]; then
    printf '%s' "$leatherman" | jq .
  else
    printf '%s' "$leatherman" | jq -r --arg path "$key_path" \
      'getpath($path | split(".")) | if type=="array" or type=="object" then . else tostring end'
  fi
}




echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m  Bootstrap\n"

if ! xcode-select -p &>/dev/null; then
    echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...installing Xcode command line tools\n"
    xcode-select --install
fi

if ! command -v brew &>/dev/null; then
    echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m ...installing brew\n"
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

brew_packages=(envchain gh git mas pandoc coreutils)
for package in "${brew_packages[@]}"; do
    if ! brew list --formula "$package" &>/dev/null; then
        brew install "$package" || error_exit "Failed to install Homebrew package: $package"
    fi
done

read "qatest_github_user?Enter the GitHub user id to use for qaTest: "
[[ -n "${qatest_github_user}" ]] || error_exit "GitHub user id is required"

switch_attempts=0
while true; do
    current_login="$(gh api user -q .login 2>/dev/null)"
    if [[ "$current_login" == "$qatest_github_user" ]]; then
        break
    fi

    echo "Active GitHub account is '${current_login:-none}'. Switching to '${qatest_github_user}'..."
    gh auth switch -u "$qatest_github_user" || error_exit "Failed to switch GitHub auth to '${qatest_github_user}'"

    current_login="$(gh api user -q .login 2>/dev/null)"
    if [[ "$current_login" == "$qatest_github_user" ]]; then
        break
    fi

    switch_attempts=$((switch_attempts + 1))
    if (( switch_attempts >= 3 )); then
        error_exit "GitHub account '${qatest_github_user}' is not active after switching attempts"
    fi
done

# Authenticate with GitHub CLI
if ! gh auth status &>/dev/null; then
    gh auth login || error_exit "GitHub authentication failed"
fi
#gh auth status || error_exit "Failed to verify GitHub authentication"

# Setup GitHub current user configuration (global)
user_email="$(gh api 'https://api.github.com/user' | jq -r .email)"
user_name="$(gh api 'https://api.github.com/user' | jq -r .name)"
if [[ -z "$user_email" || -z "$user_name" ]]; then
    echo "Warning: GitHub user email or name is empty. Please set them manually with git config --global."
else
    git config --global user.email "$user_email" || error_exit "Failed to set Git user email"
    git config --global user.name "$user_name" || error_exit "Failed to set Git user name"
fi

read "leatherman_githome?Enter the path to your GitHub folder (default is ~/GitHub): "
if [[ -z "${leatherman_githome}" ]]; then
    leatherman_githome="$HOME/GitHub"
fi
leatherman_account="qaTestLimited"
leatherman_environment="production"

for dir in development staging production; do
    create_dir "${leatherman_githome}/${leatherman_account}/${dir}"
    if [[ ! -d "${leatherman_githome}/${leatherman_account}/${dir}" ]]; then
        error_exit "Directory '${leatherman_githome}/${leatherman_account}/${dir}' does not exist after or could not be created"
    fi
done

cd "${leatherman_githome}/${leatherman_account}/${leatherman_environment}" || error_exit "Failed to navigate to directory ${leatherman_githome}/${leatherman_account}/${leatherman_environment}"

if [[ -d "leatherman" ]]; then
    read "overwrite_existing?Existing 'leatherman' directory found. Remove and re-clone? [y/N]: "
    if [[ "$overwrite_existing" == [yY] || "$overwrite_existing" == [yY][eE][sS] ]]; then
        rm -rf "leatherman" || error_exit "Failed to remove existing leatherman directory"
        gh repo clone "${leatherman_account}/leatherman" -- -b main || error_exit "Failed to clone leatherman repository"
    else
        echo "Using existing leatherman repo at ${leatherman_githome}/${leatherman_account}/${leatherman_environment}"
    fi
else
    gh repo clone "${leatherman_account}/leatherman" -- -b main || error_exit "Failed to clone leatherman repository"
fi

### Remove for production!!!!
leatherman_environment="development"

leatherman_home="${leatherman_githome}/${leatherman_account}/${leatherman_environment}/leatherman"
leatherman_script="${leatherman_home}/leatherman.sh"

qSetEnv "githome" "${leatherman_githome}"
qSetEnv "account" "${leatherman_account}"
qSetEnv "environment" "${leatherman_environment}"    
qSetEnv "home" "${leatherman_home}"    
qSetEnv "repos.${leatherman_account}.github_user" "${qatest_github_user}"

qSaveState || error_exit "Failed to save leatherman environment state"

[[ -f "${leatherman_script}" ]] || error_exit "leatherman.sh not found at ${leatherman_script}"

echo "Running q use ${leatherman_environment}"
(
    cd "${leatherman_home}" || exit 1
    source "${leatherman_script}" use ${leatherman_environment}
) || error_exit "Failed to execute leatherman.sh (use ${leatherman_environment})"
qLoadState()

echo -e "\n\e[48;5;251m   \e[0m\e[48;5;103m   \e[0m\e[48;5;240m   \e[0m Bootstrap completed"