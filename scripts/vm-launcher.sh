#!/bin/bash

# Ensure script is run with sudo
if [ "$EUID" -eq 0 ]; then
  echo -e "\e[31mPlease don't run as root\e[0m"
  exit 1
fi

# Variables
VFIO_CONF="/etc/modprobe.d/vfio.conf"
VFIO_CONF_OFF="/etc/modprobe.d/vfio.conf.off"
VM_NAME="win11"
USER_NAME="tom"
TERMINAL="wezterm"

# Function to check current GPU pass-through status
check_gpu_status() {
  if [ -f "$VFIO_CONF" ]; then
    GPU_STATUS="ENABLED"
    GPU_STATUS_COLOR="\033[32m"
    GPU_TOGGLE="DISABLE"
  else
    GPU_STATUS="DISABLED"
    GPU_STATUS_COLOR="\033[31m"
    GPU_TOGGLE="ENABLE"
  fi
}

# Function to check VM status
check_vm_status() {
  VM_STATE=$(sudo virsh domstate "$VM_NAME")
  if [[ "$VM_STATE" == "running" ]]; then
    VM_STATUS="ENABLED"
    VM_STATUS_COLOR="\033[32m"
    VM_TOGGLE="SHUTDOWN"
  else
    VM_STATUS="DISABLED"
    VM_STATUS_COLOR="\033[31m"
    VM_TOGGLE="START"
  fi
}

# Function to update GPU pass-through configuration
update_gpu_configuration() {
  if [ "$GPU_TOGGLE" == "ENABLE" ]; then
    echo "Enabling GPU pass-through..."
    if [ -f "$VFIO_CONF_OFF" ]; then
      sudo mv "$VFIO_CONF_OFF" "$VFIO_CONF"
      echo -e "GPU pass-through will be \033[32mENABLED\033[0m after reboot."
    else
      echo -e "\e[31mError: $VFIO_CONF_OFF not found. Cannot enable GPU pass-through.\e[0m"
    fi
  else
    echo "Disabling GPU pass-through..."
    if [ -f "$VFIO_CONF" ]; then
      sudo mv "$VFIO_CONF" "$VFIO_CONF_OFF"
      echo -e "GPU pass-through will be \033[31mDISABLED\033[0m after reboot."
    else
      echo -e "\e[31mError: $VFIO_CONF not found. Cannot disable GPU pass-through.\e[0m"
    fi
  fi
}

# Function to start or stop the VM
toggle_vm() {
  if [ "$VM_TOGGLE" == "START" ]; then
    echo "Starting Windows VM..."
    sudo virsh start "$VM_NAME"
  else
    echo "Shutting down Windows VM..."
    sudo virsh shutdown "$VM_NAME"
  fi
}

# Function to launch Looking Glass
launch_looking_glass() {
  echo "Launching Looking Glass... Escape key: Insert"
  nohup wezterm start -- looking-glass-client -m KEY_INSERT > /dev/null 2>&1 &
}

# Function to start VM and Looking Glass together
start_vm_and_looking_glass() {
  echo "Starting Windows VM and Looking Glass..."
  sudo virsh start "$VM_NAME"
  launch_looking_glass
}

# Main menu function
main_menu() {
  echo ""
  echo "----------------------------------------"
  check_gpu_status
  check_vm_status

  echo -e "Currently GPU pass-through is ${GPU_STATUS_COLOR}${GPU_STATUS}\033[0m."
  echo -e "Currently VM (${VM_NAME}) is ${VM_STATUS_COLOR}${VM_STATUS}\033[0m."

  echo "1. ${VM_TOGGLE} VM"
  if [[ "$VM_STATUS" == "DISABLED" && "$GPU_STATUS" == "ENABLED" ]]; then
    echo "2. Start VM + Looking Glass"
    OPTION_2_ENABLED=true
  else
    OPTION_2_ENABLED=false
  fi
  echo "3. Run Looking Glass"
  echo "4. ${GPU_TOGGLE} GPU pass-through"
  echo "5. Exit"

  read -p "Select an option: " choice

  case $choice in
    1)
      toggle_vm
      ;;
    2)
      if $OPTION_2_ENABLED; then
        start_vm_and_looking_glass
      else
        echo "Invalid option."
      fi
      ;;
    3)
      launch_looking_glass
      ;;
    4)
      update_gpu_configuration
      ;;
    5)
      exit 0
      ;;
    *)
      echo "Invalid choice, please select a valid option."
      ;;
  esac
  main_menu
}

# Start the main menu
main_menu

