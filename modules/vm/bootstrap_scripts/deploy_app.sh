#!/bin/bash
# set -ex
set -x
set -o pipefail

# version: 10Apr2023

##################################################
#############     SET GLOBALS     ################
##################################################

REPO_NAME="azure-vm-to-blob-storage"

GIT_REPO_URL="https://github.com/miztiik/$REPO_NAME.git"

APP_DIR="/var/$REPO_NAME"

LOG_FILE="/var/log/miztiik-automation-bootstrap.log"

# https://learn.microsoft.com/en-us/azure/virtual-machines/linux/tutorial-automate-vm-deployment

instruction()
{
  echo "usage: ./build.sh package <stage> <region>"
  echo ""
  echo "/build.sh deploy <stage> <region> <pkg_dir>"
  echo ""
  echo "/build.sh test-<test_type> <stage>"
}

echoerror() {
    printf "${RC} * ERROR${EC}: $@\n" 1>&2;
}

assume_role() {
  if [ -n "$DEPLOYER_ROLE_ARN" ]; then
    echo "Assuming role $DEPLOYER_ROLE_ARN ..."
  fi
}

unassume_role() {
  unset TOKEN
}

function clone_git_repo(){
  echo "Cloning Repo"
    # mkdir -p /var/
    cd /var
    git clone $GIT_REPO_URL
    cd /var/$REPO_NAME
}

function add_env_vars(){
    IMDS=`curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01"`
    declare -g USER_DATA_SCRIPT=`curl -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance/compute/userData?api-version=2021-01-01&format=text" | base64 --decode`
}

function install_libs_on_ubuntu(){
  echo "Installing Azure CLI"
  echo "Installing Azure CLI" > /var/log/miztiik_cli_install.log
  # https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

  # Initiate az login
 
  az config set extension.use_dynamic_install=yes_without_prompt
  az login --identity

  echo "Installing Python Libs"
  sudo apt-get -y install jq
  sudo apt-get -y install git
  sudo apt-get -y install python3-pip
  pip install azure-storage-blob azure-identity
}

function install_libs(){
    # Prepare the server for python3
    sudo yum -y install git jq
    sudo yum -y install python3-pip
    sudo yum -y install python3 
}

function install_nodejs(){
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash
    . ~/.nvm/nvm.sh
    nvm install node
    node -e "console.log('Running Node.js ' + process.version)"
}

function check_execution(){
    echo "hello" >/var/log/miztiik.log
}

check_execution                 | tee "${LOG_FILE}"
install_libs_on_ubuntu          | tee "${LOG_FILE}"
clone_git_repo                  | tee "${LOG_FILE}"



