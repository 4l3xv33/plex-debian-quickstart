# Plex Music Server (Ubuntu/Debian)

This repository provides a simple, reproducible setup for running Plex Media Server (music-focused) using **Docker**, with a **Makefile** to handle setup and media downloads.

The goal is:

- one command to set everything up
- a clean separation between raw downloads and final Plex media
- manual control over music metadata before Plex indexes it

## Quick Start

```
cd ~ && git clone git@github.com:4l3xv33/plex-debian-quickstart.git plex && cd plex && make setup
```

After setup, Plex will be available at `http://localhost:32400/web`.

## What `make setup` Does

`make setup` is idempotent (safe to run multiple times). It will:

**1.** Verify you’re running it from `~/plex`

**2.** Install required tools if missing:
- `yt-dlp` (media download)
- `ffmpeg` (audio extraction)
- `eyeD3` (CLI music metadata editing)
- `docker` and `docker compose`

**3.** Create the required directory structure

**4.** Warn if your user is not in the `docker` group

**5.** Start Plex via Docker Compose

If you see a warning about Docker permissions, run:

```
make docker-group
# then log out and log back in
```

## Downloading Music

Music is intentionally not downloaded directly into Plex’s library.

Instead, downloads go into an *inbox* directory:

```
make download URL="https://www.youtube.com/watch?v=..."
```

This downloads the best available audio, converts it to MP3, embeds thumbnails and basic metadata, and saves it to:

```
~/plex/inbox/music
```

## Why an Inbox?

Audio downloaded from YouTube often has:

- incorrect artist/album names
- missing track numbers
- inconsistent genres

Before Plex indexes anything, you should review and fix metadata using **eyeD3**.

Typical workflow:

**1.** Download music into `~/plex/inbox/music`

**2.** Inspect tags in the inbox (example):

```bash
eyeD3 ~/plex/inbox/music/*.mp3
```

**3.** Fix tags with `eyeD3` (example):

```bash
eyeD3 \
  --artist "Artist Name" \
  --album "Album Name" \
  --title "Track Title" \
  --track 1 \
  --genre "Genre" \
  ~/plex/inbox/music/song.mp3
```

**4.** Move finalized files into `~/plex/media/music`

**5.** Plex indexes only the cleaned library

This prevents a messy, irreversible Plex database.

## Directory Layout

```
~/plex
├── Makefile                # Setup, downloads, and Plex control
├── docker-compose.yml      # Plex container definition
│
├── config/                 # Plex configuration (Docker volume)
├── transcode/              # Plex transcode cache
│
├── media/                  # Final, organized Plex libraries
│   ├── music/              # Music Plex indexes
│   ├── movies/
│   └── tv/
│
└── inbox/                  # Staging area (not indexed by Plex)
    └── music/              # Raw downloads before metadata cleanup
```

Plex is only pointed at `media/`, never `inbox/`.

## Notes

- Designed for Ubuntu / Debian-based systems
- Requires `sudo` during initial setup
- Docker runs Plex for portability and easy restarts
- Metadata cleanup is intentionally manual for correctness
- For easy CLI metadata cleanup: `sudo apt install eyed3`
