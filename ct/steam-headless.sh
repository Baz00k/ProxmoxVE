#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: Baz00k
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Steam-Headless/docker-steam-headless

APP="Steam Headless"
var_tags="${var_tags:-gaming}"
var_cpu="${var_cpu:-4}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-20}"
var_os="${var_os:-ubuntu}"
var_version="${var_version:-24.04}"
var_unprivileged="${var_unprivileged:-0}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/steam-headless ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating ${APP}"
  $STD apt-get update
  $STD apt-get -y upgrade
  
  cd /opt/steam-headless || exit
  msg_info "Pulling latest Steam Headless Docker image"
  $STD docker-compose pull
  msg_info "Restarting Steam Headless services"
  $STD docker-compose down
  $STD docker-compose up -d
  msg_ok "Updated ${APP}"
  
  msg_info "Cleaning up"
  $STD apt-get -y autoremove
  $STD apt-get -y autoclean
  $STD docker system prune -af
  msg_ok "Cleanup complete"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access the web interface at:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8083${CL}"
echo -e "${INFO}${YW} SSH/SFTP access (for file management):${CL}"
echo -e "${TAB}${GATEWAY}${BGN}sftp://steam@${IP}:22${CL}"
echo -e "${INFO}${YW} Default credentials:${CL}"
echo -e "${TAB}${YW}Username: ${BGN}steam${CL}"
echo -e "${TAB}${YW}Password: ${BGN}password${CL}"
echo -e "${INFO}${YW} Please change the default password for security!${CL}"
