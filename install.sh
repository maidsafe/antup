#!/bin/bash

set -e

install_client=0
install_node=0

while (( "$#" )); do
  case "$1" in
    --client)
      install_client=1
      shift
      ;;
    --node)
      install_node=1
      shift
      ;;
    *) 
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ $EUID -eq 0 ]]; then
  running_as_root=1
else
  running_as_root=0
fi

function print_banner() {
  echo "**************************************"
  echo "*                                    *"
  echo "*         Installing antup           *"
  echo "*                                    *"
  echo "**************************************"
}

function detect_os() {
  os=$(uname -s)
  case "$os" in
    Linux*) os=linux ;;
    Darwin*) os=mac ;;
    *) echo "Unknown operating system"; exit 1 ;;
  esac
}

function detect_arch() {
  arch=$(uname -m)
  case "$arch" in
    x86_64*) 
      if [[ $os == "mac" ]]; then
        arch_triple="x86_64-apple-darwin"
      else
        arch_triple="x86_64-unknown-$os-musl"
      fi
      ;;
    aarch64*)
      if [[ $os == "mac" ]]; then
        arch_triple="aarch64-apple-darwin"
      else
        arch_triple="aarch64-unknown-$os-musl"
      fi
      ;;
    arm64*)
      if [[ $os == "mac" ]]; then
        echo "Mac arm64 architecture not supported, installing x86_64 version"
        arch_triple="x86_64-apple-darwin"
      else
        arch_triple="aarch64-unknown-$os-musl"
      fi
      ;;
    armv7*) arch_triple="armv7-unknown-$os-musleabihf" ;;
    *) echo "Architecture $arch not supported"; exit 1 ;;
  esac
  echo "Will retrieve antup for $arch_triple architecture"
}

function get_latest_version() {
  release_data=$(curl --silent "https://api.github.com/repos/maidsafe/antup/releases/latest")
  version=$(echo "$release_data" | awk -F': ' '/"tag_name":/ {print $2}' | \
    sed 's/"//g' | sed 's/,//g' | sed 's/v//g')
  download_url=$(echo "$release_data" | \
    awk -F': ' '/"browser_download_url":/ {print $2 $3}' | \
    grep "antup-$version-$arch_triple.tar.gz" | sed 's/"//g' | sed 's/,//g')
  echo "Latest version of antup is $version"
}

function install_antup() {
  if [[ $running_as_root -eq 1 ]]; then
    target_dir="/usr/local/bin"
  else
    target_dir="$HOME/.local/bin"
    mkdir -p "$target_dir"
    mkdir -p "$HOME/.config/autonomi"
    cat << 'EOF' > ~/.config/autonomi/env
#!/bin/sh
case ":${PATH}:" in
    *:"$HOME/.local/bin":*)
        ;;
    *)
        export PATH="$HOME/.local/bin:$PATH"
        ;;
esac
EOF
  echo "source $HOME/.config/autonomi/env" >> "$HOME/.bashrc"
  fi

  temp_dir=$(mktemp -d)
  curl -L "$download_url" -o "$temp_dir/antup.tar.gz"
  tar -xzf "$temp_dir/antup.tar.gz" -C "$temp_dir"
  mv "$temp_dir/antup" "$target_dir/antup"
  chmod +x "$target_dir/antup"
  rm -rf "$temp_dir"
  echo "antup installed to $target_dir/antup"
}

function post_install() {
  if [[ $install_client -eq 1 ]]; then
    echo "Now running antup to install the safe client..."
    $target_dir/antup client
  fi
  if [[ $install_node -eq 1 ]]; then
    echo "Now running antup to install safenode..."
    $target_dir/antup node
  fi
  if [[ $running_as_root -eq 1 ]]; then
    echo "Please run 'antup --help' to see how to install network components."
  else
    printf "\n"
    echo "The antup binary has been installed, but it's not available in this session."
    echo "You must either run 'source ~/.config/autonomi/env' in this session, or start a new session."
    echo "When antup is available, please run 'antup --help' to see how to install network components."
  fi
}

print_banner
detect_os
detect_arch
get_latest_version
install_antup
post_install