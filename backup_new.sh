#!/bin/bash -e

# --------
# SETTINGS
TMPDIR="/tmp"            # temporary directory to hold the exported db - Needs write permission
APPDATA="$(pwd)/appdata" # the directory that contains your apps - Needs read permission
BACKUPS="$(pwd)/backups" # the directory that will keep the backups - Needs write permission

# gonna test it with duplicati/duplicacy - remove if you dont need
BACKUPS_UNTAR="$BACKUPS/untar" # the directory that will keep a backups copy without compression - Needs write permission

# ---------
# VARIABLES
DATE=$(date +%F) # 2022-08-16

# bash colors
YELLOW="\033[1;33m"
GRAY="\033[1;30m"
CYAN="\033[0;36m"
GREEN="\033[1;32m"

# ------------
# START SCRIPT

# enable bash options
shopt -s nullglob extglob
# read the file in array
mapfile -t SETTINGS_CONTENT <"./settings.txt"
# number of lines
SETTINGS_LENGTH=${#SETTINGS_CONTENT[@]}

# loop over settings.txt, line by line
for ((i = 0; i <= $SETTINGS_LENGTH; i++)); do
  # escape comments; trim spaces; escape spaces for directories
  LINE=$(sed 's/#.*//g;s/[[:blank:]]*$//;s/ /\\ /g' <<<${SETTINGS_CONTENT[$i]})

  # extract a new section to backup eg: [section] the section is also the folder name
  IS_SECTION=$(sed -nE 's/\[(\w+)\]/\1/p' <<<$LINE)

  # current line is not a section and is not empty
  if [[ ! $IS_SECTION && $SECTION && $LINE ]]; then
    # WARNING: im using eval here to native resolve the globs, this is dangerous but I could not found better way, some globs wasnt being solved
    # this needs to have the full path to resolve
    eval "FILES+=($APPDATA/$SECTION/$LINE)"
  fi

  # current line is a section or is the last line
  if [[ $IS_SECTION || $i == $SETTINGS_LENGTH ]]; then

    # if it had a previous section and have files means we reach the end of section
    if [[ $SECTION && $FILES ]]; then
      # variables
      TIME=$(date +"%H-%M-%S") # 00-52-38
      TARFILE="$BACKUPS/$DATE/$SECTION.$TIME.tar.xz"

      # start a new stack to send to tar because we are filtering the database
      ARGS=()
      # look for databases inside the FILES
      for FILE in "${FILES[@]}"; do
        DEST=$FILE

        # checks if file is database
        IS_DB=$(sed -nE 's/.*\.(db|sqlite3?)$/\1/p' <<<$FILE)
        if [[ $IS_DB ]]; then
          # replace the APPDATA path with TEMPDIR path
          DEST=$(sed -n "s,^$APPDATA,$TMPDIR,p" <<<$FILE)

          echo -e "${GRAY}[$SECTION] Exporting $(basename "$FILE") to temp_dir"
          # create the temp dir
          mkdir -p "$(dirname "$DEST")"
          # call sqlite api backup
          sqlite3 "$FILE" ".backup \"$DEST\""
        fi

        # add to the stack
        ARGS+=($DEST)
      done

      echo -e "$CYAN[$SECTION] Packing $(basename "$TARFILE")"
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
        "${FILES[@]}"

      echo -e "$GRAY[$SECTION] Removing temp_dir"
      rm -rf "$TMPDIR/$SECTION"
      echo -e "$GREEN[$SECTION] Finished"
    fi

    # exit when reach last line
    [[ $i == $SETTINGS_LENGTH ]] && break

    # clean the variables for the next section
    SECTION="$IS_SECTION"
    FILES=()
    echo -e "$YELLOW[$SECTION] Started"
  fi
done
