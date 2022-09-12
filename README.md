# What to backup

```
appdata/
├── Vaultwarden/
│   ├── db.sqlite3
│   ├── rsa_key*
│   ├── config.json
│   ├── attachments/
│   └── sends/
├── Plex/
│   └── Library/
│       └── Application Support/
│           └── Plex Media Server/
│               ├── Preferences.xml
│               ├── Metadata/
│               └── Plug-in Support/
│                   └── Databases/
│                       ├── com.plexapp.plugins.library.blobs.db
│                       └── com.plexapp.plugins.library.db
├── qBittorrent/
│   ├── wireguard/
│   │   └── wg0.conf
│   ├── data/
│   │   └── BT_backup/
│   └── config/
│       ├── categories.json
│       ├── qBittorrent.conf
│       └── qBittorrent-data.conf
├── SABnzbd/
│   └── sabnzbd.ini
├── Recyclarr/
│   └── recyclarr.yml
├── Prowlarr/
│   ├── prowlarr.db
│   └── config.xml
├── Radarr/
│   ├── radarr.db
│   └── config.xml
├── Sonarr/
│   ├── sonarr.db
│   └── config.xml
├── Bazarr/
│   ├── config/
│   │   └── config.ini
│   └── db/
│       └── bazarr.db
├── Tautulli/
│   ├── tautulli.db
│   └── config.ini
└── Duplicati/
    ├── .config/
    ├── control_dir_v2/
    └── *.sqlite
```

Note about sqlite: by using the `.backup` command you dont need `-wal` file and neither to stop the container.

**But you do need to delete -wal file before restore.**

### Why is needed to delete -wal?

https://www.sqlite.org/walformat.html

> The write-ahead log or "wal" file is a roll-forward journal that records transactions that have been committed but not yet applied to the main database.

This script works on `.backup` command which is the recommended method to ensure all the WAL have been written in `.db` file. Recover a `.db` that have the stale/mismatched WAL file can cause corruption data.

The `-shm` file is just indexes and will be regenerated normal.

# How to restore

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

# Dependency

This package depends on `sqlite3` to properly backup the files, and `tar` to compress it
