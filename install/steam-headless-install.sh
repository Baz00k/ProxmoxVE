#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: Baz00k
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Steam-Headless/docker-steam-headless

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Docker"
$STD curl -fsSL https://get.docker.com | sh
$STD systemctl enable --now docker
msg_ok "Installed Docker"

msg_info "Installing Docker Compose"
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
$STD curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
$STD chmod +x /usr/local/bin/docker-compose
msg_ok "Installed Docker Compose"

msg_info "Setting up Steam Headless"
mkdir -p /opt/steam-headless/{home,games}
cd /opt/steam-headless || exit

# Create optimized docker-compose configuration
cat <<EOF > docker-compose.yml
version: '3.8'

services:
  steam-headless:
    image: josh5/steam-headless:latest
    container_name: steam-headless
    restart: unless-stopped
    shm_size: '2gb'
    ipc: shareable
    ulimits:
      nofile:
        soft: 1024
        hard: 524288
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
      - SYS_NICE
    security_opt:
      - seccomp:unconfined
      - apparmor:unconfined
    environment:
      # System Configuration
      - MODE=primary
      - WEB_UI_MODE=vnc
      - ENABLE_VNC_AUDIO=true
      - ENABLE_EVDEV_INPUTS=true
      
      # Performance Optimizations
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=all
      - PULSE_RUNTIME_PATH=/tmp/pulse
      
      # User Configuration
      - PUID=1000
      - PGID=1000
      - UMASK=000
      - USER_PASSWORD=password
      - USER_LOCALES=en_US.UTF-8 UTF-8
      - DISPLAY=:0
      
      # Steam Configuration  
      - STEAM_ARGS=
      - ADDITIONAL_PORTS=
      
    volumes:
      # Steam and game data persistence
      - ./home:/home/default:rw
      - ./games:/mnt/games:rw
      
      # System access for optimal performance
      - /tmp/.X11-unix:/tmp/.X11-unix:rw
      - /dev/shm:/dev/shm:rw
      - /dev/input:/dev/input:ro
      - /run/udev:/run/udev:ro
      
    devices:
      # Graphics and audio devices
      - /dev/dri:/dev/dri
      
    ports:
      # Web interface
      - "8083:8083"
      # VNC
      - "5900:5900"
      # SSH
      - "22:22"
      
    networks:
      - steam_network

networks:
  steam_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF

# Set proper ownership and permissions for performance
$STD chown -R 1000:1000 /opt/steam-headless
$STD chmod -R 755 /opt/steam-headless

msg_ok "Set up Steam Headless"

msg_info "Configuring system for optimal performance"

# Configure kernel parameters specifically optimized for gaming workloads
cat <<EOF > /etc/sysctl.d/99-steam-headless.conf
# Network performance optimizations for gaming
# Increase network buffer sizes to handle:
# - Large game downloads from Steam
# - Multiplayer gaming with reduced latency
# - Streaming data for remote gaming sessions
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216

# Virtual memory optimizations for gaming performance
# Reduce swap usage to keep game data in fast RAM
vm.swappiness = 10
# Optimize disk write behavior to prevent gaming stutters
# dirty_ratio: When 15% of RAM is dirty, force synchronous writes
vm.dirty_ratio = 15
# dirty_background_ratio: Start background writes at 5% to avoid sudden I/O spikes
vm.dirty_background_ratio = 5

# File system optimizations for games that open many files
# Modern games can open thousands of texture/sound/asset files simultaneously
fs.file-max = 2097152
EOF

# Apply kernel parameters
$STD sysctl -p /etc/sysctl.d/99-steam-headless.conf

# Configure system resource limits optimized for gaming workloads
cat <<EOF > /etc/security/limits.d/99-steam-headless.conf
# File descriptor limits - essential for modern games that open:
# - Hundreds of texture files
# - Multiple network connections (multiplayer)
# - Audio/video device handles
# - Shader cache files
* soft nofile 1048576
* hard nofile 1048576
# Process limits - games often spawn multiple worker threads for:
# - Physics calculations
# - Audio processing  
# - Background asset loading
# - Network communication
* soft nproc 1048576
* hard nproc 1048576
# Apply same limits to root user for system processes
root soft nofile 1048576
root hard nofile 1048576
root soft nproc 1048576
root hard nproc 1048576
EOF

msg_ok "Configured system for optimal performance"

msg_info "Starting Steam Headless"
cd /opt/steam-headless || exit
$STD docker-compose pull
$STD docker-compose up -d

# Wait for service to be ready
sleep 30
if ! docker ps | grep -q steam-headless; then
    msg_error "Steam Headless failed to start"
    exit 1
fi
msg_ok "Started Steam Headless"

# Create helper scripts
msg_info "Creating management scripts"

cat <<EOF > /usr/local/bin/steam-headless-logs
#!/bin/bash
cd /opt/steam-headless && docker-compose logs -f
EOF

cat <<EOF > /usr/local/bin/steam-headless-restart
#!/bin/bash
cd /opt/steam-headless && docker-compose restart
EOF

cat <<EOF > /usr/local/bin/steam-headless-stop
#!/bin/bash
cd /opt/steam-headless && docker-compose stop
EOF

cat <<EOF > /usr/local/bin/steam-headless-start
#!/bin/bash
cd /opt/steam-headless && docker-compose start
EOF

cat <<EOF > /usr/local/bin/steam-headless-update
#!/bin/bash
cd /opt/steam-headless && docker-compose pull && docker-compose up -d
EOF

$STD chmod +x /usr/local/bin/steam-headless-*
msg_ok "Created management scripts"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
