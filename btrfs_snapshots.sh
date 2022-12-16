#!/bin/bash

btrfs subvolume snapshot -r /mnt/cache/appdata /mnt/cache/.snapshots/appdata.$(date +%F)
# btrfs send /mnt/cache/.snapshots/appdata.$(date +%F) | btrfs receive /mnt/disks/External/snapshots
btrfs send -p /mnt/cache/.snapshots/appdata.$(date +%F -d "yesterday") /mnt/cache/.snapshots/appdata.$(date +%F) | btrfs receive /mnt/disks/External/snapshots
