# What to backup

```
appdata/
├── actual/
│   ├── server-files/
│   │   └── account.sqlite
│   └── user-files/
│       └── <hash>
│           ├── cache.sqlite
│           ├── db.sqlite
│           └── metadata.json
├── autobrr/
│   ├── autobrr.db
│   └── config.toml
├── bazarr/
│   ├── config/
│   │   └── config.ini
│   └── db/
│       └── bazarr.db
├── duplicati/
│   ├── control_dir_v2/
│   ├── Duplicati-server.sqlite
│   └── <hash>.sqlite
├── overseerr/
│   ├── db/
│   │   └── db.sqlite3
│   └── settings.json
├── plex/
│   ├── Library/
│   │   └── Application Support/
│   │       └── Plex Media Server/
│   │           ├── Plug-in Support/
│   │           │   ├── Databases/
│   │           │   │   ├── com.plexapp.plugins.library.blobs.db
│   │           │   │   └── com.plexapp.plugins.library.db
│   │           │   └── Preferences/
│   │           │       ├── com.plexapp.agents.imdb.xml
│   │           │       ├── com.plexapp.agents.localmedia.xml
│   │           │       └── com.plexapp.system.xml
│   │           └── Preferences.xml
│   ├── Plug-in Support/
│   │   ├── Databases/
│   │   │   ├── com.plexapp.plugins.library.blobs.db
│   │   │   └── com.plexapp.plugins.library.db
│   │   └── Preferences/
│   │       ├── com.plexapp.agents.imdb.xml
│   │       ├── com.plexapp.agents.localmedia.xml
│   │       └── com.plexapp.system.xml
│   └── Preferences.xml
├── prowlarr/
│   ├── config.xml
│   └── prowlarr.db
├── qbittorrent/
│   ├── config/
│   │   ├── categories.json
│   │   ├── qBittorrent-data.conf
│   │   └── qBittorrent.conf
│   ├── data/
│   │   └── BT_backup/
│   └── wireguard/
├── radarr/
│   ├── config.xml
│   └── radarr.db
├── recyclarr/
│   └── recyclarr.yml
├── sabnzbd/
│   └── sabnzbd.ini
├── sonarr/
│   ├── config.xml
│   └── sonarr.db
├── tautulli/
│   ├── config.ini
│   └── tautulli.db
├── traefik/
│   ├── certs/
│   ├── dynamic/
│   └── traefik.yml
├── uptimekuma/
│   ├── kuma.db
│   └── upload/
└── vaultwarden/
    ├── attachments/
    ├── sends/
    ├── config.json
    ├── db.sqlite3
    ├── rsa_key.pem
    └── rsa_key.pub.pem
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
