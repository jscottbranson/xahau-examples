#!/bin/bash

# This has been tested on Ubuntu 24.04

# Use the "-i" flag to install dependencies
# Use "-b" to build
# Use "-c" to clean the install directory. This will delete the user's Conan2 profile.

REPO_URL="https://github.com/jscottbranson/validator-keys-tool"
REPO_BRANCH="xahau"
BASE_DIR="$HOME"
CONAN2_DIR="${HOME}/.conan2"
CONAN2_PROFILE="${CONAN2_DIR}/profiles/default"

REPO_DIR="${REPO_URL##*/}"
REPO_DIR="${REPO_DIR%.git}"
REPO_DIR="${BASE_DIR}/${REPO_DIR}"

set -euo pipefail
IFS=$'\n\t'

do_dep_install=false
do_build=false
do_clean=false

while getopts ":ibc?h" opt; do
  case $opt in
    c) do_clean=true;;
    i) do_dep_install=true ;;
    b) do_build=true;;
    h|\?) usage; exit 0 ;;
  esac
done


# Detect if operating system is RHEL or Debian based
. /etc/os-release 2>/dev/null || { echo "unknown"; exit 1; }
OS_FAM="unknown"
case " $ID $ID_LIKE " in
  *" debian "*   ) OS_FAM="debian" ;;
  *" rhel "*|*" fedora "*|*" centos "*|*" rocky "*|*" alma "* ) OS_FAM="rhel" ;;
esac


# Clean existing build directories and Conan2 profiles
if [[ $do_clean == true ]]; then
    echo "Removing existing git repos, Python3 venv, and Conan2 profile."
    rm -rf ${REPO_DIR}
    rm -rf ${BASE_DIR}/env
    rm -rf ${CONAN2_DIR}
    echo "Cleaning complete"
fi


# Install software dependencies
if [[ $do_dep_install == true ]]; then
    echo "Installing software dependencies"
    if [[ $OS_FAM == "rhel" ]]; then
		sudo dnf install epel-release -y && sudo dnf update -y
		sudo dnf config-manager --set-enabled crb -y && sudo dnf update -y
		sudo dnf groupinstall "Development Tools" -y
		sudo dnf install curl wget git ca-certificates cmake glibc-headers glibc-devel ninja-build perl-interpreter perl perl-FindBin sqlite-devel libstdc++ libstdc++-devel libstdc++-static gcc-c++ -y
	elif [[ $OS_FAM == "debian" ]]; then
		sudo apt install -y git curl wget python3-pip python3-venv python3-dev ca-certificates gcc g++ build-essential cmake ninja-build libc6-dev
	fi
    echo "Software install complete"
fi


# Clone the Git repo & install Conan
if [[ ! -d "${REPO_DIR}" ]]; then
	cd $BASE_DIR
	git clone ${REPO_URL}
	cd $REPO_DIR
elif [[ -d "${REPO_DIR}" ]]; then
	cd $REPO_DIR
	git pull
fi

git checkout $REPO_BRANCH
mkdir ${REPO_DIR}/.build
python3 -m venv ${BASE_DIR}/env
echo "
if [ -f /opt/rh/gcc-toolset-12/enable ]; then
    case ":$PATH:" in
        *":/opt/rh/gcc-toolset-12/root/usr/bin:"*) ;;
        *) source /opt/rh/gcc-toolset-12/enable ;;
    esac
fi

export LD_LIBRARY_PATH='/opt/rh/gcc-toolset-12/root/usr/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}'
" >> ${BASE_DIR}/env/bin/activate

source ${BASE_DIR}/env/bin/activate
pip install --upgrade pip
pip install conan

if ! test -f "${CONAN2_PROFILE}"; then
    conan profile detect
fi

if grep -q '^compiler\.cppstd=' "$CONAN2_PROFILE"; then
    sed -i 's/^compiler\.cppstd=.*/compiler.cppstd=20/' "$CONAN2_PROFILE"
else
    echo 'compiler.cppstd=20' >> "$CONAN2_PROFILE"
fi

# echo "
# compiler=gcc
# compiler.version=12
# compiler.libcxx=libstdc++11
# compiler.cppstd=20" >> $CONAN2_PROFILE

if ! grep -Fqx "[conf]" "$CONAN2_PROFILE"; then
    echo "[conf]
    tools.build:cxxflags=['-Wno-restrict']" >> $CONAN2_PROFILE
fi


# Install Conan recipes
mkdir ${REPO_DIR}/external
cd ${REPO_DIR}/external

git submodule add "https://github.com/Xahau/xahaud" "xahaud"
git -C "xahaud" sparse-checkout init --cone
git -C "xahaud" sparse-checkout set "external"
git -C "xahaud" config core.worktree "$(pwd)/xahaud"
git -C "xahaud" checkout

conan export ./xahaud/external/snappy --version 1.1.10 --user xahaud --channel stable
conan export ./xahaud/external/soci --version 4.0.3 --user xahaud --channel stable


# Check for xrplf remote and add if needed
conan remote list | grep -q '^xrplf:' \
  && conan remote update --url "https://conan.ripplex.io" xrplf \
  || conan remote add --index 0 xrplf "https://conan.ripplex.io"


# build
if [[ $do_build == true ]]; then
    source ${BASE_DIR}/env/bin/activate
    cd ${REPO_DIR}/.build
    conan install .. --output-folder . --settings build_type=Release --build missing -c tools.build:verbosity=verbose -c tools.compilation:verbosity=verbose -g VirtualBuildEnv -g VirtualRunEnv
    # conan install .. --output-folder . --settings build_type=Release -s compiler=gcc -s compiler.version=12 -s compiler.libcxx=libstdc++11 -s compiler.cppstd=20 --build missing -c tools.build:verbosity=verbose -c tools.compilation:verbosity=verbose
    cmake -DCMAKE_POLICY_DEFAULT_CMP0091=NEW \
        -DCMAKE_TOOLCHAIN_FILE:FILEPATH=conan_toolchain.cmake \
        -DCMAKE_BUILD_TYPE=Release \
        ..
    cmake --build .
fi

mv ${REPO_DIR}/.build/validator-keys /${BASE_DIR}/validator-keys-portable
