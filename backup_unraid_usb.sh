#!/bin/bash -e

# extglob will enable us to do extended pattern matching for filenames
# globstar, after enabling this, by using ** we can traverse through subdirectories to search for the files
# nullglob will result in a null string if no file name is matched by our given patterns rather than the patterns themselves
shopt -s extglob globstar nullglob

# --------
# SETTINGS
CONFIG="/boot/config"            # the directory that contains unraid boot configs
BACKUPS="/mnt/user/data/backups" # the directory that will keep the backups

FILENAME="unraid-usb"            # backup file name to create inside $BACKUPS
FILES=(                          # files and directories to send to tar (needs to prepend with $CONFIG)
  # gets everything except: plugins, plugins-error, plugins-removed
  "$CONFIG/!(plugins*)"
  # gets all plugins except: dynamix.my.servers, rclone
  "$CONFIG/plugins/!(dynamix.my.servers|rclone)"
  # gets the rclone.conf
  "$CONFIG/plugins/rclone/.rclone.conf"
)

# ---------
# VARIABLES
DATE=$(date +%F)         # 2022-08-16
TIME=$(date +"%H-%M-%S") # 00-52-38

# bash colors
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
GREEN="\033[1;32m"

# ------
# BACKUP
echo -e "${YELLOW}[$FILENAME] Started"

TARFILE="$FILENAME.${TIME}.tar.xz"
echo -e "${CYAN}[$FILENAME] Packing "$TARFILE""

# tar command explained
#    c = create a new archive
#    I = compression algorithm options
#        xz compresstion with multi-thread enabled (-T0)
#    f = specify file name
mkdir -p "$BACKUPS/$DATE"
tar -cI "xz -T0" -f "$BACKUPS/$DATE/$TARFILE" ${FILES[@]}
echo -e "${GREEN}[$FILENAME] Finished"
