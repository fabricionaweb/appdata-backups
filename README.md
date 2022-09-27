## What to backup

The [settings.txt](./settings.txt) contains the files to backup. `[sections]` is the app folder and it will also be the .tar name.

By using the `.backup` command you dont need `-wal` file and neither to stop the aaplication.

**But you do need to delete -wal file before restore.**

### Why is needed to delete -wal?

https://www.sqlite.org/walformat.html

> The write-ahead log or "wal" file is a roll-forward journal that records transactions that have been committed but not yet applied to the main database.

This script works on `.backup` command which is the recommended method to ensure all the WAL have been written in `.db` file. Recover a `.db` that have the stale/mismatched WAL file can cause corruption data.

The `-shm` file is just indexes and will be regenerated normal.

## How to restore

- Stop the application you want to restore
  - Must have run at least once before
- Delete the `*-wal` file (if it exists)
  - It is in the same directly as the db
- Extract the files to the correct place
  - If your path did not change, the backup holds the correct struture folder, you can extract directly to `appdata`

Example of restore

```
# make sure of what you are doing, if you have any doubts dont delete your files but rename it instead
APPDATA="/appdata"
find "$APPDATA/vaultwarden" -name "*-wal" -delete
tar -xJvf <vaultwarden-file>.tar.xz -C $APPDATA
```

## Dependency

- sqlite3
- tar
- bash
