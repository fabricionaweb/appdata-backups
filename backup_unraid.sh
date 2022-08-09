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
  # get everything (files and folders) except: plugins* folder (plugins, plugins-error, plugins-removed)
  "$CONFIG/!(plugins*)"
  # entire folder (contain the cron jobs)
  "$CONFIG/plugins/user.scripts/scripts"
  # get any config file inside the plugins folder (since we had ignored it before)
  # you can use the folder name to identify the plugin and install it again manually
  "$CONFIG/plugins/**/*(*.cfg|*.conf|*.json|*.ini|*.xml|*.yml|*.yaml)"
)

# ---------
# VARIABLES
DATETIME=$(date +"%F_%H-%M-%S") # format 2022-08-06_11-12-07

# bash colors
YELLOW="\033[1;33m"
GRAY="\033[1;30m"
CYAN="\033[0;36m"
GREEN="\033[1;32m"

# ------
# BACKUP
echo -e "${YELLOW}[$FILENAME] Started"

TARFILE="$FILENAME.${DATETIME}.tar.xz"
echo -e "${CYAN}[$FILENAME] Packing "$TARFILE""

# tar command explained
#    c = create a new archive
#    I = compression algorithm options
#        xz compresstion with multi-thread enabled (-T0)
#    f = specify file name
tar -cI "xz -T0" -f "$BACKUPS/$TARFILE" ${FILES[@]}
echo -e "${GREEN}[$FILENAME] Finished"
