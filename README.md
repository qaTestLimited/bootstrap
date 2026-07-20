# bootstrap

Bootstrap provides a limited setup flow for qaTest Limited development.

Current functionality:

- Prompts for your GitHub home path (defaults to `~/GitHub`)
- Creates the directory structure under `qaTestLimited` for `development`, `staging`, and `production`
- Clones `qaTestLimited/leatherman` into the `production` folder
- Initialises and stores `leatherman` enviornment variables in `~/.zshrc`
- Triggers `leatherman use production` to ensure q/leatherman commands run production versions
- Triggers `leatherman install` to install any standard / user configured installs

Prerequisites:

- `zsh`

To run bootstrap, there is no need to clone this repo.  Just run the following command:

```
cd ~; source <(curl -fsSL https://raw.githubusercontent.com/qaTestLimited/bootstrap/refs/heads/main/bootstrap.sh) || { echo "Error: Failed to bootstrap"; exit 1; }
```

Notes:

- If an existing `leatherman` directory is found, bootstrap asks if you want to replace it, or use it as is.
