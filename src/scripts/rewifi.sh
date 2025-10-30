#!/usr/bin/env bash
# yes i made it vro

set -euo pipefail

# Version
VERSION="1.1.0"
SCRIPT_NAME="rewifi"

# Color codes
if [ -t 1 ]; then
  RESET='\033[0m'
  BOLD='\033[1m'
  
  # Foreground colors
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  MAGENTA='\033[0;35m'
  CYAN='\033[0;36m'
  WHITE='\033[0;37m'
  
  # Bold colors
  BRED='\033[1;31m'
  BGREEN='\033[1;32m'
  BYELLOW='\033[1;33m'
  BBLUE='\033[1;34m'
  BMAGENTA='\033[1;35m'
  BCYAN='\033[1;36m'
  BWHITE='\033[1;37m'
else
  # No colors if not a terminal
  RESET='' BOLD='' RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' WHITE=''
  BRED='' BGREEN='' BYELLOW='' BBLUE='' BMAGENTA='' BCYAN='' BWHITE=''
fi

# Nerd Font Icons (UTF-8)
ICON_WIFI=$'\uf1eb'
ICON_SUCCESS=$'\uf00c'
ICON_ERROR=$'\uf00d'
ICON_WARNING=$'\uf071'
ICON_INFO=$'\uf05a'
ICON_ARROW=$'\uf061'
ICON_CHECK=$'\uf00c'
ICON_EYE=$'\uf06e'

# Print Helpers

print_header() {
  printf "\n${BCYAN}${ICON_WIFI} WiFi-KiT: Recover WiFI Automatically${RESET}\n\n"
}

print_success() {
  printf "${BGREEN}${ICON_SUCCESS} %s${RESET}\n" "$*"
}

print_error() {
  printf "${BRED}${ICON_ERROR} %s${RESET}\n" "$*"
}

print_warning() {
  printf "${BYELLOW}${ICON_WARNING} %s${RESET}\n" "$*"
}

print_info() {
  printf "${BCYAN}${ICON_INFO} %s${RESET}\n" "$*"
}

print_step() {
  printf "${BMAGENTA}${ICON_ARROW} %s${RESET}\n" "$*"
}

print_section() {
  printf "\n${BBLUE}${ICON_INFO} %s${RESET}\n\n" "$*"
}

# Version display
show_version() {
  printf "${BCYAN}${ICON_WIFI} [wifilab] - %s v%s${RESET}\n" "$SCRIPT_NAME" "$VERSION"
  exit 0
}

# Helper Functions

cleanup_procs() {
  print_step "Terminating pentest tools (wifite/airodump/aireplay/airbase)..."

  local tools="wifite airodump-ng aireplay-ng airbase-ng"
  
  for tool in $tools; do
    if pgrep -f "$tool" >/dev/null 2>&1; then
      if sudo pkill -f "$tool" 2>/dev/null; then
        print_success "Killed $tool"
      else
        print_warning "Failed to kill $tool"
      fi
    fi
  done
  print_success "Process cleanup complete"
}

detect_iface() {
  local iface=""

  # Find non-monitor wireless interface
  iface=$(iw dev 2>/dev/null | awk '/Interface/ {print $2}' | while read -r i; do
    if iw dev "$i" info 2>/dev/null | grep -qi 'type monitor'; then
      continue
    fi
    echo "$i" && break
  done)

  # Fallback to ip link
  if [ -z "$iface" ]; then
    iface=$(ip -brief link show | awk '/wl|wlan/ {print $1; exit}')
  fi

  echo "$iface"
}

cleanup_monitor_iface() {
  local monifs
  monifs=$(iw dev 2>/dev/null | awk '
    /Interface/ {iface=$2}
    /type monitor/ {print iface}
  ')

  if [ -n "$monifs" ]; then
    echo "$monifs" | while read -r mon; do
      print_step "Found monitor interface: ${YELLOW}${mon}${RESET} → removing..."

      if command -v airmon-ng >/dev/null 2>&1; then
        sudo airmon-ng stop "$mon" 2>/dev/null || true
      fi

      if sudo iw dev "$mon" del 2>/dev/null; then
        print_success "Removed $mon"
      else
        print_warning "Failed to remove $mon"
      fi
    done
  else
    print_info "No monitor interfaces found"
  fi
}

set_managed() {
  local dev="$1"
  print_step "Configuring ${CYAN}${dev}${RESET} as managed mode..."

  sudo ip link set "$dev" down 2>/dev/null || true
  sudo iw dev "$dev" set type managed 2>/dev/null || true
  
  if sudo ip link set "$dev" up; then
    print_success "Interface set to managed mode"
  else
    print_error "Failed to set managed mode"
  fi
}

set_monitor() {
  local dev="$1"
  print_step "Configuring ${CYAN}${dev}${RESET} as monitor mode..."

  # Stop network managers that might interfere
  if systemctl is-active --quiet NetworkManager 2>/dev/null; then
    print_info "Stopping NetworkManager temporarily..."
    sudo systemctl stop NetworkManager 2>/dev/null || true
  fi

  if systemctl is-active --quiet iwd 2>/dev/null; then
    print_info "Stopping iwd temporarily..."
    sudo systemctl stop iwd 2>/dev/null || true
  fi

  # Kill interfering processes
  if command -v airmon-ng >/dev/null 2>&1; then
    sudo airmon-ng check kill 2>/dev/null || true
  fi

  # Set interface down, configure monitor mode, bring back up
  sudo ip link set "$dev" down 2>/dev/null || true
  sudo iw dev "$dev" set type monitor 2>/dev/null || true
  
  if sudo ip link set "$dev" up; then
    print_success "Interface set to monitor mode"
  else
    print_error "Failed to set monitor mode"
  fi
  
  # Verify monitor mode
  if iw dev "$dev" info 2>/dev/null | grep -qi 'type monitor'; then
    print_success "Monitor mode confirmed on $dev"
  else
    print_error "Failed to verify monitor mode"
  fi
}

restart_iwd() {
  if systemctl is-enabled --quiet iwd 2>/dev/null || systemctl status iwd >/dev/null 2>&1; then
    print_step "Restarting iwd service..."
    if sudo systemctl restart iwd; then
      print_success "iwd restarted successfully"
    else
      print_error "Failed to restart iwd"
    fi
  else
    print_warning "iwd not running as systemd service"
    print_info "If using NetworkManager/wpa_supplicant, restart those instead"
  fi
}

# Monitor mode workflow
enable_monitor_mode() {
  print_header

  # Detect interface
  local dev
  dev=$(detect_iface)

  if [ -z "$dev" ]; then
    print_error "No wireless interface detected!"
    print_info "Run ${YELLOW}iw dev${RESET} and check the output"
    exit 1
  fi

  print_success "Detected interface: ${BGREEN}${dev}${RESET}"

  # Unblock rfkill
  if command -v rfkill >/dev/null 2>&1; then
    print_step "Unblocking rfkill (removing soft blocks)..."
    if sudo rfkill unblock all; then
      print_success "rfkill unblocked"
    else
      print_warning "Failed to unblock rfkill"
    fi
  fi

  # Set to monitor mode
  set_monitor "$dev"

  print_section "Complete"
  print_success "Monitor mode enabled! ${ICON_EYE}"
  print_info "Interface ${BGREEN}${dev}${RESET} is now in monitor mode"
  printf "  ${YELLOW}• sudo airodump-ng %s${RESET}\n" "$dev"
  printf "  ${YELLOW}• sudo iwconfig %s${RESET}\n\n" "$dev"
}

# main() func
main() {
  print_header

  cleanup_procs
  cleanup_monitor_iface

  # Unblock rfkill
  if command -v rfkill >/dev/null 2>&1; then
    print_step "Unblocking rfkill (removing soft blocks)..."
    if sudo rfkill unblock all; then
      print_success "rfkill unblocked"
    else
      print_warning "Failed to unblock rfkill"
    fi
  fi

  # Detect interface
  local dev
  dev=$(detect_iface)

  if [ -z "$dev" ]; then
    print_error "No wireless interface detected!"
    print_info "Run ${YELLOW}iw dev${RESET} and check the output"
    exit 1
  fi

  print_success "Detected interface: ${BGREEN}${dev}${RESET}"

  # Set to managed mode
  set_managed "$dev" || true

  # Restart iwd
  restart_iwd

  # Wait for iwd to initialize
  print_info "Waiting for iwd to initialize..."
  sleep 2

  print_section "Complete"
  print_success "WiFi recovery process finished! ${ICON_CHECK}"
  print_info "Interface is now ready. You can now scan and connect manually using iwctl or your preferred tool."
  printf "  ${YELLOW}• sudo iwctl station %s get-networks${RESET}\n" "$dev"
  printf "  ${YELLOW}• sudo iwctl station %s connect <Your_Network>${RESET}\n\n" "$dev"
}

# Show help
show_help() {
  print_header
  print_info "Usage: $SCRIPT_NAME [OPTIONS]"
  echo ""
  printf "  ${YELLOW}-v, --version${RESET}    Show version information\n"
  printf "  ${YELLOW}--monitor${RESET}        Enable monitor mode on WiFi interface\n"
  printf "  ${YELLOW}-h, --help${RESET}       Show this help message\n"
  printf "  ${YELLOW}(no flags)${RESET}       Run normal WiFi recovery (managed mode)\n"
  echo ""
  exit 0
}

# Parser
case "${1:-}" in
  -v|--version)
    show_version
    ;;
  --monitor)
    enable_monitor_mode
    ;;
  -h|--help)
    show_help
    ;;
  "")
    main "$@"
    ;;
  *)
    print_error "Unknown option: $1"
    print_info "Use -h or --help for usage information"
    exit 1
    ;;
esac