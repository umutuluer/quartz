# ═══════════════════════════════════════════════════════════════════════
# Quartz — Multi-platform GUI toolkit build system
# ═══════════════════════════════════════════════════════════════════════
#
# Targets:
#   make [mac]     Build with macOS AppKit backend  (auto-detected)
#   make gtk       Build with Linux GTK 3 backend
#   make qt        Build with Linux Qt 5/6 backend
#   make win       Build with Windows Win32 backend
#   make examples  Build the hello_world example app
#   make clean     Remove build artifacts
#
# Environment variables:
#   QT_VERSION=6   Use Qt6 instead of Qt5  (with `make qt`)

.PHONY: all mac gtk qt win clean examples help

# ── Auto-detect platform ───────────────────────────────────────────────

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Darwin)
  BACKEND ?= mac
else ifeq ($(UNAME_S),Linux)
  BACKEND ?= gtk
else
  BACKEND ?= win
endif

# ── Backend source file ────────────────────────────────────────────────

BACKEND_SRC_mac = ext/quartz_helper_mac.m
BACKEND_SRC_gtk = ext/quartz_helper_gtk.c
BACKEND_SRC_qt  = ext/quartz_helper_qt.cpp
BACKEND_SRC_win = ext/quartz_helper_win.c

# ── Compiler and flags per backend ─────────────────────────────────────

CC_mac  = clang
CFLAGS_mac  = -c -fobjc-arc
LIBS_mac    =

CC_gtk  = gcc
CFLAGS_gtk  = -c -fPIC $$(pkg-config --cflags gtk+-3.0)
LIBS_gtk    = $$(pkg-config --libs gtk+-3.0)

QT_VERSION ?= 5
CC_qt   = g++
CFLAGS_qt   = -c -fPIC $$(pkg-config --cflags Qt$(QT_VERSION)Widgets)
LIBS_qt     = $$(pkg-config --libs Qt$(QT_VERSION)Widgets)

CC_win  = gcc
CFLAGS_win  = -c
LIBS_win    =

# ── Object output (always the same name) ───────────────────────────────

OBJ = ext/quartz_helper.o

# ═══════════════════════════════════════════════════════════════════════
# Targets
# ═══════════════════════════════════════════════════════════════════════

all: $(OBJ)

$(OBJ): ext/quartz_helper.h
	$(CC_$(BACKEND)) $(CFLAGS_$(BACKEND)) $(BACKEND_SRC_$(BACKEND)) -o $(OBJ)

mac:
	@$(MAKE) BACKEND=mac all

gtk:
	@$(MAKE) BACKEND=gtk all

qt:
	@$(MAKE) BACKEND=qt all

win:
	@$(MAKE) BACKEND=win all

# ── Example application ────────────────────────────────────────────────

examples: all
	mkdir -p bin
	crystal build examples/hello_world.cr -o bin/hello_world

# ── Clean ──────────────────────────────────────────────────────────────

clean:
	rm -f $(OBJ)
	rm -rf bin/

# ── Help ───────────────────────────────────────────────────────────────

help:
	@echo "Quartz GUI toolkit — build system"
	@echo ""
	@echo "Usage:"
	@echo "  make [mac|gtk|qt|win]  Build the platform backend"
	@echo "  make examples          Build and link the hello_world example"
	@echo "  make clean             Remove all build artifacts"
	@echo ""
	@echo "Current auto-detected backend: $(BACKEND)"
	@echo ""
	@echo "For Qt 6:  make qt QT_VERSION=6"
