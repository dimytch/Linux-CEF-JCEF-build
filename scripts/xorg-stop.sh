#!/usr/bin/env bash
sudo systemctl stop xorg-manual xorg-nvidia 2>/dev/null || true
sudo pkill -9 -f Xorg 2>/dev/null || true
sleep 1
sudo rm -f /tmp/.X0-lock /tmp/.X11-unix/X0
echo "Stopped."