# ~/plex/Makefile
# Minimal, reproducible Plex (Docker) + music download workflow (Ubuntu/Debian-ish)

SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

REPO_DIR := $(HOME)/plex

YTDLP_BIN := /usr/local/bin/yt-dlp
DOCKER_COMPOSE_BIN := /usr/local/bin/docker-compose

INBOX_MUSIC := $(HOME)/plex/inbox/music

# Prefer "docker compose" (plugin). Fall back to legacy "docker-compose".
COMPOSE := $(shell docker compose version >/dev/null 2>&1 && echo "docker compose" || echo "docker-compose")

.PHONY: help setup assert-repo dirs update-apt \
        install-ytdlp install-ffmpeg install-eyed3 install-docker install-compose \
        check-docker-group docker-group \
        up stop restart status logs pull download

help:
	@echo "Targets:"
	@echo "  make setup              - Install deps, create dirs, start Plex"
	@echo "  make up                 - Start Plex"
	@echo "  make stop               - Stop Plex"
	@echo "  make restart            - Restart Plex"
	@echo "  make status             - Show container status"
	@echo "  make logs               - Tail Plex logs"
	@echo "  make pull               - Pull latest container images"
	@echo "  make download URL=...   - Download best audio -> MP3 into inbox"
	@echo "  make docker-group       - Add current user to docker group (opt-in)"

setup: assert-repo update-apt install-ytdlp install-ffmpeg install-eyed3 install-docker install-compose check-docker-group dirs up
	@echo "Setup complete."

assert-repo:
	@if [[ "$$PWD" != "$(REPO_DIR)" ]]; then \
	  echo "ERROR: Run this from $(REPO_DIR) (repo root). Current: $$PWD"; \
	  exit 1; \
	fi
	@if [[ ! -f docker-compose.yml && ! -f compose.yml ]]; then \
	  echo "ERROR: No docker-compose.yml or compose.yml found in $$PWD"; \
	  exit 1; \
	fi

dirs:
	mkdir -p $(HOME)/plex/{config,transcode,media/{movies,tv,music},inbox/music}

update-apt:
	sudo apt-get update -y

install-ytdlp:
	@if command -v yt-dlp >/dev/null 2>&1; then \
	  echo "yt-dlp already installed: $$(yt-dlp --version)"; \
	else \
	  echo "Installing yt-dlp to $(YTDLP_BIN)"; \
	  sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o $(YTDLP_BIN); \
	  sudo chmod a+rx $(YTDLP_BIN); \
	  yt-dlp --version; \
	fi

install-ffmpeg:
	@if command -v ffmpeg >/dev/null 2>&1; then \
	  echo "ffmpeg already installed: $$(ffmpeg -version | head -n 1)"; \
	else \
	  echo "Installing ffmpeg"; \
	  sudo apt-get install -y ffmpeg; \
	  ffmpeg -version | head -n 1; \
	fi

install-eyed3:
	@if command -v eyeD3 >/dev/null 2>&1; then \
	  echo "eyeD3 already installed"; \
	else \
	  echo "Installing eyed3"; \
	  sudo apt-get install -y eyed3; \
	fi

install-docker:
	@if command -v docker >/dev/null 2>&1; then \
	  echo "docker already installed: $$(docker --version)"; \
	else \
	  echo "Installing docker.io"; \
	  sudo apt-get install -y docker.io; \
	  docker --version; \
	fi
	@# Ensure daemon is running (best-effort)
	@sudo systemctl enable --now docker >/dev/null 2>&1 || true

install-compose:
	@if docker compose version >/dev/null 2>&1; then \
	  echo "docker compose plugin already available: $$(docker compose version)"; \
	else \
	  echo "docker compose plugin not found. Trying apt install docker-compose-plugin..."; \
	  if sudo apt-get install -y docker-compose-plugin >/dev/null 2>&1; then \
	    echo "Installed docker-compose-plugin: $$(docker compose version)"; \
	  else \
	    echo "docker-compose-plugin not available via apt. Installing legacy docker-compose to $(DOCKER_COMPOSE_BIN)"; \
	    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$$(uname -s)-$$(uname -m)" \
	      -o $(DOCKER_COMPOSE_BIN); \
	    sudo chmod +x $(DOCKER_COMPOSE_BIN); \
	    $(DOCKER_COMPOSE_BIN) --version; \
	  fi; \
	fi

check-docker-group:
	@if groups | grep -q '\bdocker\b'; then \
	  echo "User is in docker group"; \
	else \
	  echo "WARNING: user is NOT in docker group."; \
	  echo "Docker commands may require sudo."; \
	  echo "To fix: make docker-group && log out / log back in"; \
	fi

docker-group:
	@echo "Adding user '$$USER' to docker group."
	@echo "This requires logout/login to take effect."
	sudo usermod -aG docker $$USER

up:
	$(COMPOSE) up -d
	@echo "Plex should be available at http://localhost:32400/web"

stop:
	$(COMPOSE) stop

restart:
	$(COMPOSE) restart

status:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f --tail=200

pull:
	$(COMPOSE) pull

# Download best audio -> MP3 into inbox
# Usage: make download URL="https://www.youtube.com/watch?v=..."
download: dirs install-ytdlp install-ffmpeg
	@test -n "$(URL)" || (echo "ERROR: Provide URL=..."; exit 1)
	yt-dlp \
	  --no-playlist \
	  -f "bestaudio/best" \
	  --extract-audio \
	  --audio-format mp3 \
	  --audio-quality 0 \
	  --embed-thumbnail \
	  --add-metadata \
	  -o "$(INBOX_MUSIC)/%(upload_date)s - %(title).200B.%(ext)s" \
	  "$(URL)"
	@echo "Saved to $(INBOX_MUSIC)"
