#!/bin/bash

# code.sh
# Author: Nils Knieling - https://github.com/Cyclenerd/google-cloud-shell-vscode

# Install and start OpenVSCode Server in Google Cloud Shell

################################################################################
#### Configuration Section
################################################################################

MY_OPENVSCODE_DIR="$HOME/openvscode-server"
MY_OPENVSCODE_HOST="127.0.0.1"
MY_OPENVSCODE_PORT="8080"

MY_OPENVSCODE_EXTENSIONS=(
	'dracula-theme.theme-dracula'
	'mechatroner.rainbow-csv'
	'hashicorp.terraform'
	'hashicorp.terraform'
)

MY_OPENVSCODE_TEMP_DOWNLOAD="/tmp/openvscodeserver.tar.gz"

################################################################################
#### END Configuration Section
################################################################################

ME=$(basename "$0")

if [[ ! $LC_CTYPE ]]; then
	export LC_CTYPE='en_US.UTF-8'
fi
if [[ ! $LC_ALL ]]; then
	export LC_ALL='en_US.UTF-8'
fi

################################################################################
# Usage
################################################################################

function usage {
	returnCode="$1"
	echo "Usage: $ME [COMMAND]"
	echo -e "COMMAND is one of the following:
	install - install latest OpenVSCode Server
	upgrade - alias for install
	start   - start OpenVSCode Server ($MY_OPENVSCODE_HOST:$MY_OPENVSCODE_PORT)
	remove  - remove OpenVSCode Server
	help    - displays help (this message)"
	exit "$returnCode"
}

################################################################################
# Terminal output helpers
################################################################################

# echo_equals() outputs a line with =
function echo_equals() {
	NCOLS=$(tput cols)
	COUNTER=0
	while [  $COUNTER -lt "$NCOLS" ]; do
		printf '='
		(( COUNTER=COUNTER+1 ))
	done
}

# echo_title() outputs a text in cyan
function echo_title() {
	tput setaf 4 0 0 # 4 = blue
	echo_equals
	echo "👉 $1"
	echo_equals
	tput sgr0  # reset terminal
	echo
}

# echo_info() outputs a text in cyan
function echo_info() {
	tput setaf 6 0 0 # 6 = cyan
	echo_equals
	echo "💡 $1"
	echo_equals
	tput sgr0  # reset terminal
}

# echo_web() outputs a text in cyan
function echo_web() {
	tput setaf 6 0 0 # 6 = cyan
	echo_equals
	echo "🧭 $1"
	echo_equals
	tput sgr0  # reset terminal
}

# echo_success() outputs a text in green.
function echo_success() {
	tput setaf 2 0 0 # 2 = green
	echo_equals
	echo "✅ OK: $1"
	echo_equals
	tput sgr0  # reset terminal
	echo
}

# echo_failure() outputs a text in red
function echo_failure() {
	tput setaf 1 0 0 # 1 = red
	echo_equals
	echo "🟥 FAILURE: $1"
	echo_equals
	tput sgr0  # reset terminal
	echo
}

# exit_with_failure() outputs a message before exiting the script.
function exit_with_failure() {
	echo_failure "$1"
	exit 1
}

################################################################################
# Other helpers
################################################################################

# command_exists() tells if a given command exists.
function command_exists() {
	command -v "$1" >/dev/null 2>&1
}

################################################################################
# OpenVSCode
################################################################################

function install_openvscode() {
	echo_title "Install OpenVSCode Server"
	MY_LAST_VERSION_URL="$(curl -fsSLI -o /dev/null -w "%{url_effective}" https://github.com/gitpod-io/openvscode-server/releases/latest)"
	# 0 = OK
	# 1 = command line tools are already installed
	if [ "$?" -gt 1 ]; then
		exit_with_failure "Failed to get last version"
	fi
	MY_LAST_VERSION="${MY_LAST_VERSION_URL#https://github.com/gitpod-io/openvscode-server/releases/tag/openvscode-server-v}"

	if [ ! -d "$MY_OPENVSCODE_DIR" ]; then
		mkdir "$MY_OPENVSCODE_DIR" || exit_with_failure "Failed to create dir '$MY_OPENVSCODE_DIR'"
	fi
	if [ -d "$MY_OPENVSCODE_DIR/openvscode-server-v${MY_LAST_VERSION}-linux-x64" ]; then
		# already downloaded and unzipped
		echo_info "OpenVSCode Server version $MY_LAST_VERSION already installed. Download is skipped."
	else
		MY_DOWNLOAD_URL="https://github.com/gitpod-io/openvscode-server/releases/download/openvscode-server-v${MY_LAST_VERSION}/openvscode-server-v${MY_LAST_VERSION}-linux-x64.tar.gz"
		# Download
		echo "Download '$MY_DOWNLOAD_URL', please wait..."
		curl -L "$MY_DOWNLOAD_URL" -o "$MY_OPENVSCODE_TEMP_DOWNLOAD" || exit_with_failure "Failed to download dir '$MY_DOWNLOAD_URL'"
		# Extract
		echo "Extract '$MY_OPENVSCODE_TEMP_DOWNLOAD', please wait..."
		tar -xzf "$MY_OPENVSCODE_TEMP_DOWNLOAD" -C "$MY_OPENVSCODE_DIR" || exit_with_failure "Failed to extract '$MY_OPENVSCODE_TEMP_DOWNLOAD'"
		ln -sf "$MY_OPENVSCODE_DIR/openvscode-server-v${MY_LAST_VERSION}-linux-x64" "$MY_OPENVSCODE_DIR/latest" || exit_with_failure "Failed to link to latest version"
		rm "$MY_OPENVSCODE_TEMP_DOWNLOAD" || exit_with_failure "Failed to remove temp. download '$MY_OPENVSCODE_TEMP_DOWNLOAD'"
	fi

	echo "Install extensions, please wait..."
	for MY_OPENVSCODE_EXTENSION in "${MY_OPENVSCODE_EXTENSIONS[@]}"; do
		"$MY_OPENVSCODE_DIR/latest/bin/openvscode-server" --install-extension "$MY_OPENVSCODE_EXTENSION" --force
	done
	
	echo_success "Installed successfully. You can start OpenVSCode Server now."
}

function start_openvscode() {
	echo_title "Start OpenVSCode Server"
	MY_OPENVSCODE_SERVER="$MY_OPENVSCODE_DIR/latest/bin/openvscode-server"
	if [ -x "$MY_OPENVSCODE_SERVER" ]; then
		gcloud auth list
		MY_CLOUDSHELL_URL=$("cloudshell get-web-preview-url -p $MY_OPENVSCODE_PORT")
		echo_web "You can open OpenVSCode using this URL $MY_CLOUDSHELL_URL"
		sleep 3
		"$MY_OPENVSCODE_SERVER" --without-connection-token --host "$MY_OPENVSCODE_HOST" --port "$MY_OPENVSCODE_PORT" || exit_with_failure "Cannot start OpenVSCode Server '$MY_OPENVSCODE_SERVER'"
	else
		exit_with_failure "Cannot find last version of OpenVSCode Server '$MY_OPENVSCODE_SERVER'. Please install OpenVSCode Server."
	fi
}

function remove_openvscode() {
	echo_title "Remove OpenVSCode Server"
	rm -rf "$MY_OPENVSCODE_DIR" || exit_with_failure "Cannot remove OpenVSCode Server and delete dir '$MY_OPENVSCODE_DIR'."
	echo_success "Successfully deleted."
}

################################################################################
# MAIN
################################################################################

if ! command_exists tput; then
	exit_with_failure "'tput' is needed. Please install 'tput' ('ncurses')."
fi

if ! command_exists curl; then
	exit_with_failure "'curl' is needed. Please install 'curl'."
fi

if ! command_exists gcloud; then
	exit_with_failure "'gcloud' is needed. Please install Google Cloud CLI ('gcloud')."
fi

case "$1" in
"")
	# called without arguments
	start_openvscode
	;;
"start")
	start_openvscode
	;;
"install" | "update")
	install_openvscode
	;;
"remove")
	remove_openvscode
	;;
"h" | "help" | "-h" | "-help" | "-?" | *)
	usage 0
	;;
esac