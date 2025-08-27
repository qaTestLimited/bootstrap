# bootstrap

Bootstrap is used to configure your local machine ready for working at qaTest Limited.  It will install the tools needed to manage your applications, repositories and development environments.

To run bootstrap, there is no need to clone this repo.  Just run the following command:

```
cd ~; source <(curl -fsSL https://raw.githubusercontent.com/qaTestLimited/bootstrap/refs/heads/main/bootstrap.sh) || { echo "Error: Failed to bootstrap"; exit 1; }
```
