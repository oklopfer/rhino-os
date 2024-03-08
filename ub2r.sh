#!/bin/bash

# Colors
if [[ -z $NO_COLOR ]]; then
  export RED=$'\033[0;31m'
  export GREEN=$'\033[0;32m'
  export YELLOW=$'\033[0;33m'
  export BLUE=$'\033[0;34m'
  export PURPLE=$'\033[0;35m'
  export CYAN=$'\033[0;36m'
  export WHITE=$'\033[0;37m'
  export BGreen=$'\033[1;32m'
  export BCyan=$'\033[1;36m'
  export BYellow=$'\033[1;33m'
  export BBlue=$'\033[1;34m'
  export BPurple=$'\033[1;35m'
  export BRed=$'\033[1;31m'
  export BWhite=$'\033[1;37m'
  export NC=$'\033[0m'
  export BOLD=$'\033[1m'
fi

function cleanup() {
  if [[ -f "/etc/apt/sources.list-rhino.bak" ]]; then
    echo "[${BCyan}~${NC}] ${BOLD}NOTE${NC}: Returning ${CYAN}/etc/apt/sources.list${NC} backup"
    sudo rm -f /etc/apt/sources.list
    sudo mv /etc/apt/sources.list-rhino.bak /etc/apt/sources.list
  fi
}

function get_releaseinfo() {
  source /etc/os-release
  if [[ ${ID} != "ubuntu" ]]; then
    echo "[${BRed}!${NC}] ${BOLD}ERROR${NC}: not an Ubuntu system!"
    exit 1
  elif [[ ${NAME} != "Rhino Linux" ]]; then
    echo "[${BGreen}+${NC}] ${BOLD}INFO${NC}: detected Ubuntu ${BPurple}${VERSION_CODENAME}${NC} system."
  fi
}

function ask() {
  local prompt default reply

  if [[ ${2-} == 'Y' ]]; then
    prompt="${BGreen}Y${NC}/${BRed}n${NC}"
    default='Y'
  elif [[ ${2-} == 'N' ]]; then
    prompt="${BGreen}y${NC}/${BRed}N${NC}"
    default='N'
  else
    prompt="${BGreen}y${NC}/${BRed}n${NC}"
  fi

  # Ask the question (not using "read -p" as it uses stderr not stdout)
  echo -ne "$1 [$prompt] "

  if [[ ${DISABLE_PROMPTS:-z} == "z" ]]; then
    export DISABLE_PROMPTS="no"
  fi

  if [[ $DISABLE_PROMPTS == "no" ]]; then
    read -r reply <&0
    # Detect if script is running non-interactively
    # Which implies that the input is being piped into the script
    if [[ $NON_INTERACTIVE ]]; then
      if [[ -z $reply ]]; then
        echo -n "$default"
      fi
      echo "$reply"
    fi
  else
    echo "$default"
    reply=$default
  fi

  # Default?
  if [[ -z $reply ]]; then
    reply=$default
  fi

  while :; do
    # Check if the reply is valid
    case "$reply" in
      Y* | y*)
        export answer=1
        return 0 #return code for backwards compatibility
        break
        ;;
      N* | n*)
        export answer=0
        return 1 #return code
        break
        ;;
      *)
        echo -ne "$1 [$prompt] "
        read -r reply < /dev/tty
        ;;
    esac
  done
}

function echo_repo_config() {
  local uri_source="$1" suite="$2" sec="$3" selected_uri_dir="ubuntu" architectures
  case "$uri_source" in
    ports)
      selected_uri_source="ports"
      architectures="amd64 i386"
      selected_uri_dir="ubuntu-ports"
      ;;
    archive)
      selected_uri_source="archive"
      architectures="arm64"
      ;;
    security)
      selected_uri_source="security"
      architectures="arm64"
      ;;
    *)
      return 1
    ;;
  esac
  echo "Types: deb"
  echo "URIs: http://${selected_uri_source}.ubuntu.com/${selected_uri_dir}/"
  if [[ ${sec} == "security" ]]; then
    echo "Suites: ${suite}-security"
  else
    echo "Suites: ${suite} ${suite}-updates ${suite}-backports"
  fi
  echo "Components: main universe restricted multiverse"
  echo "Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg"
  echo "Architectures-Remove: ${architectures}"
  echo ""
}

function update_sources() {
  echo "[${BYellow}*${NC}] ${BOLD}WARNING${NC}: Updating ${CYAN}/etc/apt/sources.list${NC} entries to ${BPurple}./devel${NC}. If you have any PPAs, they may break!"
  ask "[${BYellow}*${NC}] Continue?" N
  if ((answer == 0)); then
    echo "[${BGreen}+${NC}] ${BOLD}INFO${NC}: No changes made. Exiting..."
    exit 0
  else
    echo "[${BCyan}~${NC}] ${BOLD}NOTE${NC}: Creating backup of ${CYAN}/etc/apt/sources.list${NC}..."
    sudo mv /etc/apt/sources.list /etc/apt/sources.list-rhino.bak
    if [[ $(dpkg --print-architecture) == "arm64" ]]; then
      echo_repo_config "ports" "./devel" | sudo tee /etc/apt/sources.list.d/rhino.sources > /dev/null
      echo_repo_config "ports" "./devel" "security" | sudo tee -a /etc/apt/sources.list.d/rhino.sources > /dev/null
    else
      echo_repo_config "archive" "./devel" | sudo tee /etc/apt/sources.list.d/rhino.sources > /dev/null
      echo_repo_config "security" "./devel" "security" | sudo tee -a /etc/apt/sources.list.d/rhino.sources > /dev/null
    fi
  fi
}

function install_pacstall() {
  if ! [[ -f "/usr/bin/pacstall" ]]; then
    echo "[${BGreen}+${NC}] ${BOLD}INFO${NC}: Installing Pacstall..."
    echo -e "Y\nN" | sudo bash -c "$(curl -fsSL https://pacstall.dev/q/install || wget -q https://pacstall.dev/q/install -O -)"
  fi
}

function unicorn_flavor() {
  sudo update-alternatives --install /usr/share/icons/default/index.theme x-cursor-theme /usr/share/icons/Quintom_Snow/cursor.theme 55
  sudo update-alternatives --install /usr/share/icons/default/index.theme x-cursor-theme /usr/share/icons/Quintom_Ink/cursor.theme 55
  sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/rhino-spinner/rhino-spinner.plymouth 100
  sudo update-alternatives --set default.plymouth /usr/share/plymouth/themes/rhino-spinner/rhino-spinner.plymouth
  sudo update-alternatives --set x-cursor-theme /usr/share/icons/Quintom_Ink/cursor.theme
  echo "export QT_STYLE_OVERRIDE=kvantum" | sudo tee -a /etc/environment > /dev/null
  mkdir -p /home/$USER/.config/Kvantum
  echo "theme=KvRhinoDark" >> /home/$USER/.config/Kvantum/kvantum.kvconfig
  sudo rm /etc/lightdm/lightdm-gtk-greeter.conf
  (cd /etc/lightdm/ && sudo wget https://raw.githubusercontent.com/rhino-linux/lightdm/main/lightdm-gtk-greeter.conf && sudo wget https://github.com/rhino-linux/lightdm/raw/main/rhino-blur.png)
  rm -rf /home/$USER/.config/xfce4
  mkdir -p /home/$USER/.config/xfce4
  mkdir -p /home/$USER/.config/Kvantum
  cp -r /etc/skel/.config/xfce4/* /home/$USER/.config/xfce4
  cp -r /etc/skel/.config/Kvantum/* /home/$USER/.config/Kvantum
  ln -s "/home/$USER/.config/xfce4/desktop/icons.screen0-1904x990.rc" "/home/$USER/.config/xfce4/desktop/icons.screen.latest.rc"
  chmod -R 777 /home/$USER/.config/xfce4
  sudo chown $USER -cR /home/$USER/.config
}

function select_core() {
  echo "[${BCyan}~${NC}] ${BOLD}NOTE${NC}: Rhino Linux has three versions of our app suite. Which would you like to install?"
  echo "[${BBlue}>${NC}] ${BOLD}1)${NC} ${BPurple}rhino-server-core${NC}: TUI tool suite w/ basic development tools"
  echo "[${BBlue}>${NC}] ${BOLD}2)${NC} ${BPurple}rhino-ubxi-core${NC}: TUI+GUI app suite w/ GTK applications"
  echo "[${BBlue}>${NC}] ${BOLD}3)${NC} ${BPurple}rhino-core${NC}: Full suite w/ Unicorn Desktop Environment"
  unset packages core_package
  while true; do
    read -p "[${BYellow}*${NC}] Enter your choice (${BGreen}1${NC}/${BGreen}2${NC}/${BGreen}3${NC}): " choice
    case $choice in
      1)
        core_package="rhino-server-core"
        packages=("nala-deb" "${core_package}")
        break
        ;;
      2)
        core_package="rhino-ubxi-core"
        packages=("nala-deb" "celeste-bin" "timeshift" "${core_package}")
        break
        ;;
      3)
        core_package="rhino-core"
        packages=("nala-deb" "celeste-bin" "timeshift" "quintom-cursor-theme-git" "${core_package}" "rhino-setup-bin")
        break
        ;;
      *) ;;
    esac
  done
  echo "[${BGreen}+${NC}] ${BOLD}INFO${NC}: Selected to install ${BPurple}${core_package}${NC}."
}

function select_kernel() {
  echo "[${BCyan}~${NC}] ${BOLD}NOTE${NC}: Rhino Linux ships two versions of the Ubuntu mainline kernel:"
  echo "[${BBlue}>${NC}] ${BOLD}1)${NC} ${BPurple}linux-kernel${NC}: tracks the kernel ${YELLOW}mainline${NC} branch, with versions ${CYAN}X${NC}.${CYAN}X${NC}.${CYAN}0${NC}{${CYAN}-rcX${NC}}"
  echo "[${BBlue}>${NC}] ${BOLD}2)${NC} ${BPurple}linux-kernel-stable${NC}: tracks the kernel ${YELLOW}stable${NC} branch, with versions ${CYAN}X${NC}.(${CYAN}X-1${NC}).${CYAN}X${NC}"
  echo "[${BBlue}>${NC}] Would you like to install either of them? You can also say ${BRed}N${NC}/${BRed}n${NC} to remain on your current kernel."
  unset kern_package
  while true; do
    read -p "[${BYellow}*${NC}] Enter your choice (${BGreen}1${NC}/${BGreen}2${NC}/${BRed}N${NC}): " choice
    case $choice in
      1)
        kern_package="linux-kernel"
        break
        ;;
      2)
        kern_package="linux-kernel-stable"
        break
        ;;
      N | n)
        kern_package="none"
        break
        ;;
      *) ;;
    esac
  done
  if [[ ${kern_package} != "none" ]]; then
    echo "[${BGreen}+${NC}] ${BOLD}INFO${NC}: Selected to install ${BPurple}${kern_package}${NC}."
  else
    echo "[${BGreen}+${NC}] ${BOLD}INFO${NC}: Will not install any new kernels."
  fi
}

function install_packages() {
  echo "[${BCyan}~${NC}] ${BOLD}NOTE${NC}: Upgrading packages, this may take a while..."
  sudo apt-get update --allow-releaseinfo-change && sudo DEBIAN_FRONTEND=noninteractive apt-get install base-files postfix -yq && sudo apt-get full-upgrade -y || exit 1
  if [[ ${kern_package} != "none" ]]; then
    echo "[${BCyan}~${NC}] ${BOLD}NOTE${NC}: Installing ${BPurple}${kern_package}${NC}..."
    pacstall -PI ${kern_package} || exit 1
  else
    echo "[${BCyan}~${NC}] ${BOLD}NOTE${NC}: Not installing any kernels."
  fi
  echo "[${BCyan}~${NC}] ${BOLD}NOTE${NC}: Installing ${BPurple}${core_package}${NC} suite..."
  pacstall -PI ${packages[*]} || exit 1
  if [[ ${core_package} == "rhino-core" ]]; then
    unicorn_flavor
  fi
}

echo "[${BPurple}#${NC}] ${BOLD}Welcome to ub2r: A utility to convert Ubuntu to Rhino Linux${NC}"

get_releaseinfo
install_pacstall || exit 1

if [[ ${NAME} != "Rhino Linux" ]]; then
  trap "cleanup && exit 1" EXIT
  trap "cleanup && exit 1" INT
  update_sources || {
    cleanup
    exit 1
  }
  select_kernel || {
    cleanup
    exit 1
  }
  select_core || {
    cleanup
    exit 1
  }
  echo "[${BGreen}+${NC}] ${BOLD}INFO${NC}: All set! We'll do the rest. Starting in 5 seconds..."
  sleep 5
  if install_packages; then
    echo "[${BCyan}~${NC}] ${BOLD}NOTE${NC}: Removing ${CYAN}/etc/apt/sources.list${NC} backup..."
    sudo rm -f /etc/apt/sources.list-rhino.bak
    neofetch --ascii_distro rhino_small
    echo "[${BGreen}+${NC}] ${BOLD}INFO${NC}: Complete! You can now use ${BPurple}rhino-pkg${NC}/${BPurple}rpk${NC} to manage your packages."
    echo "[${BBlue}>${NC}] Be sure to reboot when you are done checking it out!"
  else
    cleanup
    exit 1
  fi
else
  echo "[${BGreen}+${NC}] ${BOLD}INFO${NC}: Rhino Linux appears to already be installed."
  ask "[${BYellow}*${NC}] Do you want to change kernels and/or suites?" N
  if ((answer == 0)); then
    echo "[${BCyan}~${NC}] No changes made. Exiting..."
    exit 0
  else
    select_kernel || exit 1
    select_core || exit 1
    echo "[${BGreen}+${NC}] ${BOLD}INFO${NC}: All set! Starting in 3 seconds..."
    sleep 3
    if install_packages; then
      echo "[${BGreen}+${NC}] ${BOLD}INFO${NC}: Complete! Be sure to reboot if you installed any new kernels."
    else
      exit 1
    fi
  fi
fi
