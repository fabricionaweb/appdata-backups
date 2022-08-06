# What to backup

Note about sqlite: by using the `.backup` tool you dont need `*-wal` file neither stop the container, but you do need to delete it before restore.

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
│   └── qBittorrent/
│       ├── categories.json
│       ├── qBittorrent.conf
│       ├── qBittorrent-data.conf
│       └── BT_backup/
├── SABnzbd/
│   └── sabnzbd.ini
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
└── Tautulli/
    ├── tautulli.db
    └── config.ini
```

# Dependency

This package depends on `sqlite3` to properly backup the files, and `tar` to compress it
