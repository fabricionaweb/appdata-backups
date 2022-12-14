#!/bin/bash -e

# --------
# SETTINGS
TMPDIR="/tmp"                    # temporary directory to hold the exported db - Needs write permission
APPDATA="/mnt/user/appdata"      # the directory that contains your apps - Needs read permission
BACKUPS="/mnt/user/data/backups" # the directory that will keep the backups - Needs write permission
SETTINGS="./settings.txt"        # txt containg the list of files to backup

# remove if you dont need
BACKUPS_UNTAR="$BACKUPS/untar" # the directory that will keep a backups copy without compression - Needs write permission

# ---------
# VARIABLES
DATE=$(date +%F) # 2022-08-16

# bash colors
YELLOW="\033[1;33m"
GRAY="\033[1;30m"
CYAN="\033[0;36m"
GREEN="\033[1;32m"

# ---------
# FUNCTIONS

export_database() {
  # params
  local FILE="$1"
  local DEST="$2"

  # create the temp dir
  mkdir -p "$(dirname "$DEST")"
  # call sqlite api backup to save the backup in TMPDIR
  sqlite3 "$FILE" ".backup \"$DEST\""
}

create_tar() {
  # params
  local TARFILE="$1"
  shift
  local ARGS=("$@")

  # create the backup folder
  mkdir -p "$(dirname "$TARFILE")"
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
  tar -cI "xz -T0" -f "$TARFILE" \
    --transform "s,^$TMPDIR/,,;s,^$APPDATA/,," \
    --absolute-names --ignore-failed-read \
    "${ARGS[@]}"
}

extract_tar() {
  # params
  local TARFILE="$1"

  mkdir -p "$BACKUPS_UNTAR"
  # the file we create contain the app folder
  tar -xJf "$TARFILE" -C "$BACKUPS_UNTAR"
}

start_backup() {
  # params
  local SECTION="$1"
  shift
  local FILES=("$@")

  # variables
  TIME=$(date +"%H-%M-%S") # 00-52-38
  TARFILE="$BACKUPS/$DATE/$SECTION.$TIME.tar.xz"
  # start a new stack to send to tar because we are filtering the database from FILES
  ARGS=()

  # loop over FILES to check if exists and if is database (to export it)
  for FILE in "${FILES[@]}"; do
    # if the file or directory doesnt exist do nothing
    [[ ! -f $FILE && ! -d $FILE ]] && continue

    # checks if file is a database
    IS_DB=$(sed -nE 's/.*\.(db|sqlite3?)$/\1/p' <<<$FILE)
    # if is not a database the source will remaing the same
    DEST=$FILE

    if [[ $IS_DB ]]; then
      # if is a database replace the path APPDATA to TMPDIR
      DEST=$(sed -n "s,^$APPDATA,$TMPDIR,p" <<<$FILE)

      # export the database to TMPDIR
      echo -e "$GRAY[$SECTION] Exporting $(basename "$FILE") to temp_dir"
      export_database "$FILE" "$DEST"
    fi

    # add SRC to the new stack
    ARGS+=("$DEST")
  done

  # no file found or glob resolved, nothing to backup
  if [[ ! $ARGS ]]; then
    echo -e "$GRAY[$SECTION] Nothing to backup"
    return
  fi

  # creates the tar file
  echo -e "$CYAN[$SECTION] Packing $(basename "$TARFILE")"
  create_tar "$TARFILE" "${ARGS[@]}"

  # if you also want to save an uncompress copy
  if [[ $BACKUPS_UNTAR ]]; then
    echo -e "$CYAN[$SECTION] Unpacking $(basename "$TARFILE")"
    # remove old backups
    rm -rf "$BACKUPS_UNTAR/$SECTION" 2>/dev/null
    extract_tar "$TARFILE" & # run in background
  fi

  echo -e "$GRAY[$SECTION] Removing temp_dir"
  rm -rf "$TMPDIR/$SECTION"
  echo -e "$GREEN[$SECTION] Finished"
}

# ------------
# START SCRIPT

# read the file and save in array
mapfile -t SETTINGS_CONTENT <$SETTINGS
# number of lines in the file
SETTINGS_LENGTH=${#SETTINGS_CONTENT[@]}

# loop over settings.txt, line by line
for ((i = 0; i <= $SETTINGS_LENGTH; i++)); do
  # escape comments; trim spaces; escape spaces for directories
  LINE=$(sed 's/#.*//g;s/[[:blank:]]*$//;s/ /\\ /g' <<<${SETTINGS_CONTENT[$i]})
  # extract a section to backup eg: [section] the section is also the folder name
  IS_SECTION=$(sed -nE 's/\[(\w+)\]/\1/p' <<<$LINE)

  # current line is not empty, is not a section and it has a previous section declared (means it is file)
  if [[ $LINE && ! $IS_SECTION && $SECTION ]]; then
    # WARNING: im using eval here to native resolve the globs, this is dangerous but I could not found better way, some globs wasnt being solved
    # it needs to have the full path to bash resolve the globs
    # later we check if the file exists
    eval "shopt -s globstar extglob; FILES+=($APPDATA/$SECTION/$LINE)"
  fi

  # current line is a section or reach the end of the file
  if [[ $IS_SECTION || $i == $SETTINGS_LENGTH ]]; then

    # it had a previous section and have files (means we are changing sections, we reach the end of a section)
    if [[ $SECTION && $FILES ]]; then
      start_backup "$SECTION" "${FILES[@]}"
    fi

    # reach the end of the file, stop the loop
    [[ $i == $SETTINGS_LENGTH ]] && break

    # set the variables for the next section
    SECTION="$IS_SECTION"
    FILES=()
    echo -e "$YELLOW[$SECTION] Started"
  fi
done

# untar can be running in background
wait
