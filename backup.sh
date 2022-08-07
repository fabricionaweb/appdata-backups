#!/bin/bash -e

# --------
# SETTINGS
APPDATA="$(pwd)/appdata" # the directory that contains your apps - Needs read permission
BACKUPS="$(pwd)/backups" # the directory that will keep the backups - Needs write permission
TMPDIR="/tmp" # temporary directory to hold the exported db - Needs write permission

# ---------
# VARIABLES
DATETIME=$(date +"%F_%H-%M-%S") # format 2022-08-06_11-12-07

# bash colors
YELLOW="\033[1;33m"
GRAY="\033[1;30m"
CYAN="\033[0;36m"
GREEN="\033[1;32m"

# ---------
# FUNCTIONS
export_backup() {
  local FILENAME="$1"
  local APPDIR="$2"
  local DB="$3"

  local SOURCE="$APPDATA/$APPDIR/$DB"
  local DEST="$TMPDIR/$APPDIR/$DB"
  echo -e "${GRAY}[$FILENAME] Exporting $(basename "$SOURCE") to temp_dir"

  # needs to create the path in temp dir (will ifnore if already exists)
  mkdir -p "$(dirname "$DEST")"
  echo ".backup \""$DEST"\"" | sqlite3 "$SOURCE"
}

compress_backup() {
  local FILENAME="$1"
  shift
  local FILES=("$@")

  # tar destination file
  local TARFILE="$FILENAME.${DATETIME}.tar.xz"
  echo -e "${CYAN}[$FILENAME] Packing "$TARFILE""

  # tar command explained
  #    c = create a new archive
  #    I = compression algorithm options
  #        xz compresstion with multi-thread enabled (-T0)
  #    f = specify file name
  #    --transform = use sed replace EXPRESSION to transform files (from inside the tar)
  #        "s,<find>,<replace>," format
  #        we are removing the "/tmp" ($TMPDIR) and "/appdata" ($APPDATA) from the archive
  #        the goal is to make a flat archive
  #    --absolute-names = don't strip leading '/'s from file names
  #        it is needed to apply our --transform sed (or need to change it)
  #    --ignore-failed-read = do not exit with nonzero on unreadable files
  #        if something goes wrong it will not stop the tar, but you should always verify that
  tar -cI "xz -T0" -f "$BACKUPS/$TARFILE" \
    --transform "s,^$TMPDIR/,,;s,^$APPDATA/,," \
    --absolute-names --ignore-failed-read \
    "${FILES[@]}"
}

remove_tmp() {
  local FILENAME="$1"
  local APPDIR="$2"

  echo -e "${GRAY}[$FILENAME] Removing temp_dir"
  rm -rf "$TMPDIR/$APPDIR/$DB"
}

# ------------
# APPLICATIONS
vaultwarden() {
  # vaultwarden/
  # ├── db.sqlite3
  # ├── rsa_key*
  # ├── config.json
  # ├── attachments/
  # └── sends/
  local FILENAME="vaultwarden" # backup file name to create inside $BACKUPS
  local APPDIR="vaultwarden"   # directory inside $APPDATA
  local DBS=("db.sqlite3")     # database to export (inside $APPDATA)
  local FILES=(                # files and directories to send to tar (inside $APPDATA)
    "config.json"              # file
    "rsa_key*"                 # glob pattern (for $FILES only) use wisely or avoid
    "attachments"              # directory
    "sends"                    # directory
  )

  # start the script
  echo -e "${YELLOW}[$FILENAME] Started"
  local ARGS=() # will keep the files to pass to tar
  for DB in "${DBS[@]}"; do
    export_backup "$FILENAME" "$APPDIR" "$DB"; ARGS+=("$TMPDIR/$APPDIR/$DB");
  done
  for FILE in "${FILES[@]}"; do
    local GLOB; readarray -t GLOB < <(compgen -G "$APPDATA/$APPDIR/$FILE"); ARGS+=("${GLOB[@]}");
  done
  compress_backup "$FILENAME" "${ARGS[@]}"
  remove_tmp "$FILENAME" "$APPDIR"
  echo -e "${GREEN}[$FILENAME] Finished"
}

plex() {
  # plex/
  # └── Library/
  #     └── Application Support/
  #         └── Plex Media Server/
  #             ├── Preferences.xml
  #             ├── Metadata/
  #             └── Plug-in Support/
  #                 └── Databases/
  #                     ├── com.plexapp.plugins.library.db
  #                     └── com.plexapp.plugins.library.blobs.db
  local FILENAME="plex"
  local APPDIR="plex/Library/Application Support/Plex Media Server"
  local DBS=(
    "Plug-in Support/Databases/com.plexapp.plugins.library.db"
    "Plug-in Support/Databases/com.plexapp.plugins.library.blobs.db"
  )
  local FILES=(
    "Preferences.xml"
    "Metadata" # directory
  )

  # start the script
  echo -e "${YELLOW}[$FILENAME] Started"
  local ARGS=() # will keep the files to pass to tar
  for DB in "${DBS[@]}"; do
    export_backup "$FILENAME" "$APPDIR" "$DB"; ARGS+=("$TMPDIR/$APPDIR/$DB");
  done
  for FILE in "${FILES[@]}"; do
    local GLOB; readarray -t GLOB < <(compgen -G "$APPDATA/$APPDIR/$FILE"); ARGS+=("${GLOB[@]}");
  done
  compress_backup "$FILENAME" "${ARGS[@]}"
  remove_tmp "$FILENAME" "$APPDIR"
  echo -e "${GREEN}[$FILENAME] Finished"
}

# -------
# EXECUTE
vaultwarden
plex
