#!/bin/bash -e

# --------
# SETTINGS
APPDATA="$(pwd)/appdata" # the directory that contains your apps - Needs read permission
BACKUPS="$(pwd)/backups" # the directory that will keep the backups - Needs write permission
TMPDIR="/tmp" # temporary directory to hold the exported db - Needs write permission

# ---------
# VARIABLES
DATETIME=$(date +"%F_%H-%M-%S") # format 2022-08-06_11-12-07
EXTENSION="tar.xz" # extension pass to tar compression

# bash colors
YELLOW="\033[1;33m"
GRAY="\033[1;30m"
CYAN="\033[0;36m"
GREEN="\033[1;32m"

# ------------
# APPLICATIONS

vaultwarden() {
  # backup file name to create inside $BACKUPS
  local FILENAME="vaultwarden"
  # directory inside $APPDATA
  local APPDIR="vaultwarden"
  # database to export (inside $APPDATA)
  local DBS=(
    "db.sqlite3"
  )
  # files to compress (inside $APPDATA)
  local FILES=(
    "config.json" # file
    "rsa_key*" # glob pattern allowed
    "attachments" # directory
    "sends" # directory
  )

  echo -e "${YELLOW}[vaultwarden] Started"

  # path of dbs to pass to tar
  local DBSARG=""

  # iterate $DBS to export and save in $TMPDIR
  for DB in ${DBS[@]}; do
    local SOURCE="$APPDATA/$APPDIR/$DB"
    local DEST="$TMPDIR/$APPDIR/$DB"

    # needs to create the path
    mkdir -p "$(dirname "$DEST")"

    echo -e "${GRAY}[vaultwarden] Exporting "$SOURCE" to "$DEST""
    sqlite3 $SOURCE ".backup "$DEST""

    # realpath only works if the file exists
    DBSARG+=" $(realpath "$DEST")"
  done

  # paths of files to pass to tar
  local FILESARG=""

  # iterate over $FILES to make the string to pass to tar
  for FILE in ${FILES[@]}; do
    FILESARG+=" $(realpath "$APPDATA/$APPDIR/$FILE")"
  done

  # tar destination file
  local TARFILE="$BACKUPS/$FILENAME.${DATETIME}.${EXTENSION}"
  echo -e "${CYAN}[vaultwarden] Packing "$TARFILE""

  # tar command explained
  #    c = create a new archive
  #    a = use archive suffix to determine the compression program
  #    f = use archive file
  #    --transform = use sed replace EXPRESSION to transform files (from inside the tar)
  #        "s,<find>,<replace>," format
  #        we are removing the "/tmp" and "appdata" directories from the archive
  #        the goal is to make a flat archive
  #    --absolute-names = don't strip leading '/'s from file names
  #        it is needed to apply the --transform sed
  #    --ignore-failed-read = do not exit with nonzero on unreadable files
  tar caf "$TARFILE" \
      --transform "s,$TMPDIR/,,;s,$APPDATA/,," \
      --absolute-names --ignore-failed-read \
      $DBSARG $FILESARG

  echo -e "${GREEN}[vaultwarden] Finished"
}

# -------
# EXECUTE
vaultwarden
