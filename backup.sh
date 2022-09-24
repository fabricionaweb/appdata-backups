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
  #    --transform = use sed replace EXPRESSION to transform files (inside the tar)
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
  # plex/ (hotio)
  # ├── Preferences.xml
  # ├── Metadata/
  # └── Plug-in Support/
  #     ├── Preferences/
  #     └── Databases/
  #         ├── com.plexapp.plugins.library.db
  #         └── com.plexapp.plugins.library.blobs.db
  local FILENAME="plex"
  local APPDIR="plex"
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

jellyfin() {
  # jellyfin/ (lsio and hotio)
  # ├── data/
  # │   ├── data/
  # │   │   ├── device.txt
  # │   │   ├── jellyfin.db
  # │   │   └── library.db
  # │   ├── plugins/
  # │   └── root/
  # │       └── default/
  # │           └── Movies/
  # │               ├── movies.mblink
  # │               ├── movies.collection
  # │               └── options.xml
  # ├── branding.xml
  # ├── dlna.xml
  # ├── encoding.xml
  # ├── metadata.xml
  # ├── migrations.xml
  # ├── network.xml
  # ├── system.xml
  # └── xbmcmetadata.xml
  local FILENAME="jellyfin"
  local APPDIR="jellyfin"
  local DBS=(
    "data/data/jellyfin.db"
    "data/data/library.db"
  )
  local FILES=(
    "data/plugins/configurations" # directory
    "data/root"                   # directory
    "data/plugins"                # directory
    "data/data/device.txt"
    "*.xml"
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
  # prowlarr/ (lsio and hotio)
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
  # radarr/ (lsio and hotio)
  # ├── radarr.db
  # └── config.xml
  local FILENAME="radarr"
  local APPDIR="radarr"
  local DBS=("radarr.db")
  local FILES=(
    "config.xml"
    "*.{sh,py}" # custom scripts
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

sonarr() {
  # sonarr/ (lsio and hotio)
  # ├── sonarr.db
  # └── config.xml
  local FILENAME="sonarr"
  local APPDIR="sonarr"
  local DBS=("sonarr.db")
  local FILES=(
    "config.xml"
    "*.{sh,py}" # custom scripts
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

bazarr() {
  # bazarr/ (lsio and hotio)
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
  # tautulli/ (lsio and hotio)
  # ├── newsletters/ (optional)
  # ├── tautulli.db
  # └── config.ini
  local FILENAME="tautulli"
  local APPDIR="tautulli"
  local DBS=("tautulli.db")
  local FILES=(
    "newsletters" # directory
    "config.ini"
    "*.{sh,py}"   # custom scripts
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

qbittorrent() {
  # qbittorrent/ (hotio)
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
  # sabnzbd/ (lsio and hotio)
  # ├── scripts/
  # └── sabnzbd.ini
  local FILENAME="sabnzbd"
  local APPDIR="sabnzbd"
  local FILES=(
    "scripts" # directory
    "sabnzbd.ini"
  )

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
  # overseerr/ (lsio and hotio)
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
  # duplicati/ (lsio)
  # ├── .config/
  # ├── control_dir_v2/
  # └── *.sqlite
  local FILENAME="duplicati"
  local APPDIR="duplicati"
  local DBS=("*.sqlite")
  local FILES=(
    ".config"        # directory
    "control_dir_v2" # directory
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

uptimekuma() {
  # uptimekuma/
  # ├── upload/
  # └── kuma.db
  local FILENAME="uptimekuma"
  local APPDIR="uptimekuma"
  local DBS=("kuma.db")
  local FILES=(
    "upload" # directory
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

traefik() {
  # traefik/
  # ├── certs/
  # ├── dynamic/
  # └── traefik.yaml
  local FILENAME="traefik"
  local APPDIR="traefik"
  local FILES=(
    "certs"   # directory
    "certs"   # directory
    "dynamic" # directory
    "*.{yaml,yml,toml}"
  )

  # start the script
  echo -e "${YELLOW}[$FILENAME] Started"
  local ARGS=() # will keep the files to pass to tar
  for FILE in "${FILES[@]}"; do local GLOB; readarray -t GLOB < <(compgen -G "$APPDATA/$APPDIR/$FILE"); ARGS+=("${GLOB[@]}"); done
  compress_backup "$FILENAME" "${ARGS[@]}"
  remove_tmp "$FILENAME" "$APPDIR"
  echo -e "${GREEN}[$FILENAME] Finished"
}

autobrr() {
  # autobrr/
  # ├── autobrr.db
  # └── config.toml
  local FILENAME="autobrr"
  local APPDIR="autobrr"
  local DBS=("autobrr.db")
  local FILES=(
    "config.toml"
    "*.{sh,py}" # custom scripts
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

actualbudge() {
  # actual/
  # ├── server-files/
  # │   └── account.sqlite
  # └── user-files/
  #     └── 2470124b-0d8c-49fa-a076-6de5f6af89a9
  #         ├── cache.sqlite
  #         ├── db.sqlite
  #         └── metadata.json
  local FILENAME="actual"
  local APPDIR="actual"
  local DBS=(
    "server-files/account.sqlite"
    "user-files/**/*.sqlite"
  )
  local FILES=(
    "user-files/**/metadata.json"
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
jellyfin &
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
uptimekuma &
traefik &
autobrr &
actualbudge &

wait
