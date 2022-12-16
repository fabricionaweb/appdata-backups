#!/bin/bash -e

# --------
# SETTINGS
BACKUPS="/mnt/user/data/backups"  # source directory that contains the backups
EXCLUDE="$BACKUPS/.rclone-ignore" # file contain what should be ignored

# ---------
# VARIABLES

# bash colors
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
CLEAR="\033[0m" # No Color

# ----
# COPY
cmd_copy() {
  local SERVICE="$1"
  local DEST="$2"

  echo -e "$YELLOW[$SERVICE] Started $CLEAR"
  rclone rmdirs $SERVICE:"$DEST" --leave-root
  rclone copy "$BACKUPS" $SERVICE:"$DEST" --max-age 7d --exclude-from $EXCLUDE --log-level "ERROR"
  echo -e "$GREEN[$SERVICE] Finished $CLEAR"
}

# --------
# SERVICES

# One Drive
one_drive() {
  local SERVICE="OneDrive" # service name (rclone listremotes)
  local DEST="Backups"     # remote destination path

  # cleanup
  rclone delete $SERVICE:"$DEST" --min-age 30d

  cmd_copy $SERVICE $DEST
}

# Google Drive
google_drive() {
  local SERVICE="GoogleDrive" # service name (rclone listremotes)
  local DEST="Backups"        # remote destination path

  # cleanup
  rclone delete $SERVICE:"$DEST" --min-age 30d

  cmd_copy $SERVICE $DEST
}

# Dropbox
dropbox() {
  local SERVICE="Dropbox" # service name (rclone listremotes)
  local DEST="Backups"    # remote destination path

  # cleanup
  rclone delete $SERVICE:"$DEST" --min-age 10d

  cmd_copy $SERVICE $DEST
}

# -------
# EXECUTE (in paralell)
one_drive &
google_drive &
dropbox &

wait
