#!/bin/bash -e

# --------
# SETTINGS
TMPDIR="/tmp"                    # temporary directory to hold the exported db - Needs write permission
APPDATA="/mnt/user/appdata"      # the directory that contains your apps - Needs read permission
BACKUPS="/mnt/user/data/backups" # the directory that will keep the backups - Needs write permission

# gonna test it with duplicati/duplicacy - remove if you dont need
BACKUPS_UNTAR="${BACKUPS}/untar" # the directory that will keep a backups copy without compression - Needs write permission

# ---------
# VARIABLES
DATE=$(date +%F)         # 2022-08-16
TIME=$(date +"%H-%M-%S") # 00-52-38

# bash colors
YELLOW="\033[1;33m"
GRAY="\033[1;30m"
CYAN="\033[0;36m"
GREEN="\033[1;32m"

# -----
# STEPS
export_backup() {
  local FILENAME="$1"
  local APPDIR="$2"
  local DB="$3"

  local SOURCE="$APPDATA/$APPDIR/$DB"
  local DEST="$TMPDIR/$APPDIR/$DB"
  echo -e "${GRAY}[$FILENAME] 1/3 Exporting $(basename "$SOURCE") to temp_dir"

  # needs to create the path in temp dir (will ignore if already exists)
  mkdir -p "$(dirname "$DEST")"
  echo ".backup \""$DEST"\"" | sqlite3 "$SOURCE"
}

compress_backup() {
  local FILENAME="$1"
  shift
  local FILES=("$@")

  local TARFILE="$FILENAME.${TIME}.tar.xz"
  echo -e "${CYAN}[$FILENAME] 2/3 Packing "$TARFILE""

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
  mkdir -p "$BACKUPS/$DATE"
  tar -cI "xz -T0" -f "$BACKUPS/$DATE/$TARFILE" \
    --transform "s,^$TMPDIR/,,;s,^$APPDATA/,," \
    --absolute-names --ignore-failed-read \
    "${FILES[@]}"

  # save a uncompress copy
  if [[ "$BACKUPS_UNTAR" ]]; then
    mkdir -p "$BACKUPS_UNTAR"
    echo -e "${CYAN}[$FILENAME] 2/3 Extrating copy "$TARFILE""
    tar -xJf "$BACKUPS/$DATE/$TARFILE" -C "$BACKUPS_UNTAR"
  fi
}

remove_tmp() {
  local FILENAME="$1"
  local APPDIR="$2"

  echo -e "${GRAY}[$FILENAME] 3/3 Removing temp_dir"
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
  local FILENAME="vaultwarden" # backup file name to create (inside $BACKUPS)
  local APPDIR="vaultwarden"   # directory (inside $APPDATA)
  local DBS=("db.sqlite3")     # database to export (inside $APPDATA/$APPDIR)
  local FILES=(                # files and directories to send to tar (inside $APPDATA/$APPDIR)
    "config.json"              # file
    "rsa_key*"                 # glob pattern (for $FILES only) use wisely or avoid
    "attachments"              # directory
    "sends"                    # directory
  )

  # start the script
  echo -e "${YELLOW}[$FILENAME] Started"
  local ARGS=() # will keep the files to pass to tar
  for DB in "${DBS[@]}"; do export_backup "$FILENAME" "$APPDIR" "$DB"; ARGS+=("$TMPDIR/$APPDIR/$DB"); done
  for FILE in "${FILES[@]}"; do local GLOB; readarray -t GLOB < <(compgen -G "$APPDATA/$APPDIR/$FILE"); ARGS+=("${GLOB[@]}"); done
  compress_backup "$FILENAME" "${ARGS[@]}"
  remove_tmp "$FILENAME" "$APPDIR"
  echo -e "${GREEN}[$FILENAME] Finished"
}

plex() {
  # plex/ (from lsio image)
  # └── Library/
  #     └── Application Support/
  #         └── Plex Media Server/
  #             ├── Preferences.xml
  #             ├── Metadata/
  #             └── Plug-in Support/
  #                 ├── Preferences/
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
    "Plug-in Support/Preferences" # directory
    "Preferences.xml"
  )

  # start the script
  echo -e "${YELLOW}[$FILENAME] Started"
  local ARGS=() # will keep the files to pass to tar
  for DB in "${DBS[@]}"; do export_backup "$FILENAME" "$APPDIR" "$DB"; ARGS+=("$TMPDIR/$APPDIR/$DB"); done
  for FILE in "${FILES[@]}"; do local GLOB; readarray -t GLOB < <(compgen -G "$APPDATA/$APPDIR/$FILE"); ARGS+=("${GLOB[@]}"); done
  compress_backup "$FILENAME" "${ARGS[@]}"
  remove_tmp "$FILENAME" "$APPDIR"
  echo -e "${GREEN}[$FILENAME] Finished"
}

prowlarr() {
  # prowlarr/ (from lsio image)
  # ├── prowlarr.db
  # └── config.xml
  local FILENAME="prowlarr"
  local APPDIR="prowlarr"
  local DBS=("prowlarr.db")
  local FILES=("config.xml")

  # start the script
  echo -e "${YELLOW}[$FILENAME] Started"
  local ARGS=() # will keep the files to pass to tar
  for DB in "${DBS[@]}"; do export_backup "$FILENAME" "$APPDIR" "$DB"; ARGS+=("$TMPDIR/$APPDIR/$DB"); done
  for FILE in "${FILES[@]}"; do local GLOB; readarray -t GLOB < <(compgen -G "$APPDATA/$APPDIR/$FILE"); ARGS+=("${GLOB[@]}"); done
  compress_backup "$FILENAME" "${ARGS[@]}"
  remove_tmp "$FILENAME" "$APPDIR"
  echo -e "${GREEN}[$FILENAME] Finished"
}

radarr() {
  # radarr/ (from lsio image)
  # ├── radarr.db
  # └── config.xml
  local FILENAME="radarr"
  local APPDIR="radarr"
  local DBS=("radarr.db")
  local FILES=("config.xml")

  # start the script
  echo -e "${YELLOW}[$FILENAME] Started"
  local ARGS=() # will keep the files to pass to tar
  for DB in "${DBS[@]}"; do export_backup "$FILENAME" "$APPDIR" "$DB"; ARGS+=("$TMPDIR/$APPDIR/$DB"); done
  for FILE in "${FILES[@]}"; do local GLOB; readarray -t GLOB < <(compgen -G "$APPDATA/$APPDIR/$FILE"); ARGS+=("${GLOB[@]}"); done
  compress_backup "$FILENAME" "${ARGS[@]}"
  remove_tmp "$FILENAME" "$APPDIR"
  echo -e "${GREEN}[$FILENAME] Finished"
}

sonarr() {
  # sonarr/ (from lsio image)
  # ├── sonarr.db
  # └── config.xml
  local FILENAME="sonarr"
  local APPDIR="sonarr"
  local DBS=("sonarr.db")
  local FILES=("config.xml")

  # start the script
  echo -e "${YELLOW}[$FILENAME] Started"
  local ARGS=() # will keep the files to pass to tar
  for DB in "${DBS[@]}"; do export_backup "$FILENAME" "$APPDIR" "$DB"; ARGS+=("$TMPDIR/$APPDIR/$DB"); done
  for FILE in "${FILES[@]}"; do local GLOB; readarray -t GLOB < <(compgen -G "$APPDATA/$APPDIR/$FILE"); ARGS+=("${GLOB[@]}"); done
  compress_backup "$FILENAME" "${ARGS[@]}"
  remove_tmp "$FILENAME" "$APPDIR"
  echo -e "${GREEN}[$FILENAME] Finished"
}

bazarr() {
  # bazarr/ (from lsio image)
  # ├── config/
  # │   └── config.ini
  # └── db/
  #     └── bazarr.db
  local FILENAME="bazarr"
  local APPDIR="bazarr"
  local DBS=("db/bazarr.db")
  local FILES=("config/config.ini")

  # start the script
  echo -e "${YELLOW}[$FILENAME] Started"
  local ARGS=() # will keep the files to pass to tar
  for DB in "${DBS[@]}"; do export_backup "$FILENAME" "$APPDIR" "$DB"; ARGS+=("$TMPDIR/$APPDIR/$DB"); done
  for FILE in "${FILES[@]}"; do local GLOB; readarray -t GLOB < <(compgen -G "$APPDATA/$APPDIR/$FILE"); ARGS+=("${GLOB[@]}"); done
  compress_backup "$FILENAME" "${ARGS[@]}"
  remove_tmp "$FILENAME" "$APPDIR"
  echo -e "${GREEN}[$FILENAME] Finished"
}

tautulli() {
  # tautulli/ (from lsio image)
  # ├── tautulli.db
  # └── config.ini
  local FILENAME="tautulli"
  local APPDIR="tautulli"
  local DBS=("tautulli.db")
  local FILES=("config.ini")

  # start the script
  echo -e "${YELLOW}[$FILENAME] Started"
  local ARGS=() # will keep the files to pass to tar
  for DB in "${DBS[@]}"; do export_backup "$FILENAME" "$APPDIR" "$DB"; ARGS+=("$TMPDIR/$APPDIR/$DB"); done
  for FILE in "${FILES[@]}"; do local GLOB; readarray -t GLOB < <(compgen -G "$APPDATA/$APPDIR/$FILE"); ARGS+=("${GLOB[@]}"); done
  compress_backup "$FILENAME" "${ARGS[@]}"
  remove_tmp "$FILENAME" "$APPDIR"
  echo -e "${GREEN}[$FILENAME] Finished"
}

qbittorrent() {
  # qbittorrent/ (from hotio image)
  # ├── wireguard/
  # │   └── wg0.conf
  # ├── data/
  # │   └── BT_backup/
  # └── config/
  #     ├── categories.json
  #     ├── qBittorrent.conf
  #     └── qBittorrent-data.conf
  local FILENAME="qbittorrent"
  local APPDIR="qbittorrent"
  local FILES=(
    "wireguard/wg0.conf"
    "config/categories.json"
    "config/qBittorrent.conf"
    "config/qBittorrent-data.conf"
    "data/BT_backup" # directory
  )

  # start the script
  echo -e "${YELLOW}[$FILENAME] Started"
  local ARGS=() # will keep the files to pass to tar
  for FILE in "${FILES[@]}"; do local GLOB; readarray -t GLOB < <(compgen -G "$APPDATA/$APPDIR/$FILE"); ARGS+=("${GLOB[@]}"); done
  compress_backup "$FILENAME" "${ARGS[@]}"
  remove_tmp "$FILENAME" "$APPDIR"
  echo -e "${GREEN}[$FILENAME] Finished"
}

sabnzbd() {
  # sabnzbd/ (from lsio image)
  # └── sabnzbd.ini
  local FILENAME="sabnzbd"
  local APPDIR="sabnzbd"
  local FILES=("sabnzbd.ini")

  # start the script
  echo -e "${YELLOW}[$FILENAME] Started"
  local ARGS=() # will keep the files to pass to tar
  for FILE in "${FILES[@]}"; do local GLOB; readarray -t GLOB < <(compgen -G "$APPDATA/$APPDIR/$FILE"); ARGS+=("${GLOB[@]}"); done
  compress_backup "$FILENAME" "${ARGS[@]}"
  remove_tmp "$FILENAME" "$APPDIR"
  echo -e "${GREEN}[$FILENAME] Finished"
}

recyclarr() {
  # recyclarr/
  # └── recyclarr.yml
  local FILENAME="recyclarr"
  local APPDIR="recyclarr"
  local FILES=("recyclarr.yml")

  # start the script
  echo -e "${YELLOW}[$FILENAME] Started"
  local ARGS=() # will keep the files to pass to tar
  for FILE in "${FILES[@]}"; do local GLOB; readarray -t GLOB < <(compgen -G "$APPDATA/$APPDIR/$FILE"); ARGS+=("${GLOB[@]}"); done
  compress_backup "$FILENAME" "${ARGS[@]}"
  remove_tmp "$FILENAME" "$APPDIR"
  echo -e "${GREEN}[$FILENAME] Finished"
}

overseerr() {
  # overseerr/ (from lsio image)
  # ├── settings.json
  # └── db/
  #     └── db.sqlite3
  local FILENAME="overseerr"
  local APPDIR="overseerr"
  local DBS=("db/db.sqlite3")
  local FILES=("settings.json")

  # start the script
  echo -e "${YELLOW}[$FILENAME] Started"
  local ARGS=() # will keep the files to pass to tar
  for DB in "${DBS[@]}"; do export_backup "$FILENAME" "$APPDIR" "$DB"; ARGS+=("$TMPDIR/$APPDIR/$DB"); done
  for FILE in "${FILES[@]}"; do local GLOB; readarray -t GLOB < <(compgen -G "$APPDATA/$APPDIR/$FILE"); ARGS+=("${GLOB[@]}"); done
  compress_backup "$FILENAME" "${ARGS[@]}"
  remove_tmp "$FILENAME" "$APPDIR"
  echo -e "${GREEN}[$FILENAME] Finished"
}

duplicati() {
  # duplicati/ (from lsio image)
  # ├── .config/
  # ├── control_dir_v2/
  # └── *.sqlite
  local FILENAME="duplicati"
  local APPDIR="duplicati"
  local DBS=("*.sqlite")
  local FILES=(
    ".config"
    "control_dir_v2"
  )

  # start the script
  echo -e "${YELLOW}[$FILENAME] Started"
  local ARGS=() # will keep the files to pass to tar

  # this whole loop is only needed when doing glob for $DBS
  for DB in "${DBS[@]}"; do local GLOB; readarray -t GLOB < <(compgen -G "$APPDATA/$APPDIR/$DB")
    for DB_PATH in "${GLOB[@]}"; do local DB_FILE=$(echo "$DB_PATH" | sed "s,^$APPDATA/$APPDIR/,,") # remove absolute path from glob
      export_backup "$FILENAME" "$APPDIR" "$DB_FILE"; ARGS+=("$TMPDIR/$APPDIR/$DB_FILE")
    done
  done

  for FILE in "${FILES[@]}"; do local GLOB; readarray -t GLOB < <(compgen -G "$APPDATA/$APPDIR/$FILE"); ARGS+=("${GLOB[@]}"); done
  compress_backup "$FILENAME" "${ARGS[@]}"
  remove_tmp "$FILENAME" "$APPDIR"
  echo -e "${GREEN}[$FILENAME] Finished"
}

# -------
# EXECUTE (in paralell)
vaultwarden &
plex &
prowlarr &
radarr &
sonarr &
bazarr &
tautulli &
qbittorrent &
sabnzbd &
recyclarr &
overseerr &
duplicati &

wait
