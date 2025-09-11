#!/bin/bash
#
exit 0

# Major Steps:
# PowerWash the machine
# Create Administrator Account
# Invoke AppleID
# First Login (as admin)
# Set HostName(s)
# Install xcode-devtools
# Add SJS Account
# Set Remote Management
# Install Chrome
# Install golang
# Install TailScale
# Install TailScaled
# Activate Tailscale
# Login SJS confirmation

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

# Detailed instructions

# PowerWash the machine
# Settings: Transfer: ...

# Create Administrator Account
#  Full Name: Administrator
#  Account: admin
#  Password: Hound Dog

# Invoke AppleID
# simssj@gmail.com

# First Login (as admin)

# Set HostName(s)
MachineName="cfam-$(ifconfig en0 | grep ether | awk '{print $NF}' | tr ':' '-' )"
for name in HostName LocalHostName ComputerName; do 
   sudo scutil --set "${name}" "${MachineName}"
done

# This takes a while so start it now:
# Install xcode-devtools
xcode-select --install

# Add SJS Account

# Set Remote Management
# Go to Settings: Sharing...

# Install Chrome
https://www.google.com/chrome/

# Install golang
https://golang.org/dl/

# After the xcode devtools are installed:
# Install TailScale
# Guide: https://github.com/tailscale/tailscale/wiki/Tailscaled-on-macOS
sudo /usr/local/go/bin/go install tailscale.com/cmd/tailscale{,d}@main

# Install Tailscaled:
sudo $HOME/go/bin/tailscaled install-system-daemon

# Activate Tailscale
sudo $HOME/go/bin/tailscale up --accept-routes=true

# Verify Tailscale:
sudo $HOME/go/bin/tailscale status

# Login SJS confirmation
