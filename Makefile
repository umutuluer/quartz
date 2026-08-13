# ═══════════════════════════════════════════════════════════════════════
# Quartz — Multi-platform GUI toolkit build system
# ═══════════════════════════════════════════════════════════════════════
#
# Targets:
#   make [mac|gtk|qt|win]  Build the platform backend
#   make examples           Build the hello_world example
#   make clean              Remove build artifacts
#   make help               Show this help
#
# Variables:
#   BACKEND=gtk|qt|mac|win  Override auto-detected backend
#   QT_VERSION=5|6          Select Qt version (auto-detected)

.DEFAULT_GOAL := help
.PHONY: all mac gtk qt win examples clean help

# ═══════════════════════════════════════════════════════════════════════
# Platform detection
# ═══════════════════════════════════════════════════════════════════════

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Darwin)
  BACKEND ?= mac
else ifeq ($(UNAME_S),Linux)
  BACKEND ?= qt
else
  BACKEND ?= win
endif

# ── Qt version (Linux, auto-detected) ──────────────────────────────────

QT_VERSION ?= $(shell pkg-config --exists Qt6Widgets && echo 6 || \
                         (pkg-config --exists Qt5Widgets && echo 5 || echo 6))

# ═══════════════════════════════════════════════════════════════════════
# Per-backend configuration
# ═══════════════════════════════════════════════════════════════════════

# Source file
SRC_mac  = ext/quartz_helper_mac.m
SRC_gtk  = ext/quartz_helper_gtk.c
SRC_qt   = ext/quartz_helper_qt.cpp
SRC_win  = ext/quartz_helper_win.c

# Compiler
CC_mac  = clang
CC_gtk  = gcc
CC_qt   = g++
CC_win  = gcc

# Compile flags
CFLAGS_mac  = -c -fobjc-arc
CFLAGS_gtk  = -c -fPIC $(shell pkg-config --cflags gtk+-3.0)
CFLAGS_qt   = -c -fPIC $(shell pkg-config --cflags Qt$(QT_VERSION)Widgets)
CFLAGS_win  = -c

# Link flags → passed to `crystal build --link-flags` for the example app.
# macOS frameworks are embedded in src/quartz/lib_quartz.cr via @[Link].
LDFLAGS_mac  =
LDFLAGS_gtk  = $(shell pkg-config --libs gtk+-3.0)
LDFLAGS_qt   = $(shell pkg-config --libs Qt$(QT_VERSION)Widgets) -lstdc++
LDFLAGS_win  = -lgdi32 -luser32 -lcomctl32

# Current backend values (computed once from BACKEND)
SRC    = $(SRC_$(BACKEND))
CC     = $(CC_$(BACKEND))
CFLAGS = $(CFLAGS_$(BACKEND))
LDFLAGS = $(LDFLAGS_$(BACKEND))

# Crystal compile-time flags mirroring the selected backend.
# These are required by src/quartz/lib_quartz.cr so that the @[Link]
# directives resolve to the right pkg-config libraries.
CRYSTAL_FLAGS_gtk  = -Dquartz_backend_gtk
CRYSTAL_FLAGS_qt   = -Dquartz_backend_qt$(QT_VERSION)
CRYSTAL_FLAGS_mac  =
CRYSTAL_FLAGS_win  =
CRYSTAL_FLAGS      = $(CRYSTAL_FLAGS_$(BACKEND))

# ═══════════════════════════════════════════════════════════════════════
# Build artifacts
# ═══════════════════════════════════════════════════════════════════════
#
# Each backend compiles to its own object file so that switching
# backends (e.g. `make gtk` after `make qt`) does not leave a stale
# object around to confuse the linker. `make clean` removes all of
# them.

OBJ_mac = ext/quartz_helper_mac.o
OBJ_gtk = ext/quartz_helper_gtk.o
OBJ_qt  = ext/quartz_helper_qt.o
OBJ_win = ext/quartz_helper_win.o
OBJ_all = $(OBJ_mac) $(OBJ_gtk) $(OBJ_qt) $(OBJ_win)

OBJ  = $(OBJ_$(BACKEND))
BIN  = bin/hello_world
BIN_LB = bin/listbox_example
BIN_COMBO = bin/combobox_example
BIN_CB = bin/checkbox_example
BIN_RB = bin/radiobutton_example
BIN_OFD = bin/openfiledialog_example
BIN_SFD = bin/savefiledialog_example

# ═══════════════════════════════════════════════════════════════════════
# Targets
# ═══════════════════════════════════════════════════════════════════════

all: $(OBJ)  ## Build the platform backend

$(OBJ_mac): $(SRC_mac) ext/quartz_helper.h
	$(CC_mac) $(CFLAGS_mac) $(SRC_mac) -o $@

$(OBJ_gtk): $(SRC_gtk) ext/quartz_helper.h
	$(CC_gtk) $(CFLAGS_gtk) $(SRC_gtk) -o $@

$(OBJ_qt): $(SRC_qt) ext/quartz_helper.h
	$(CC_qt) $(CFLAGS_qt) $(SRC_qt) -o $@

$(OBJ_win): $(SRC_win) ext/quartz_helper.h
	$(CC_win) $(CFLAGS_win) $(SRC_win) -o $@

mac:  ## Build with macOS AppKit backend
	@$(MAKE) BACKEND=mac all

gtk:  ## Build with Linux GTK 3 backend
	@$(MAKE) BACKEND=gtk all

qt:   ## Build with Linux Qt 5/6 backend
	@$(MAKE) BACKEND=qt all

win:  ## Build with Windows Win32 backend
	@$(MAKE) BACKEND=win all

# ── Example ────────────────────────────────────────────────────────────

examples: $(OBJ)  ## Build all example applications
	@mkdir -p bin
	crystal build $(CRYSTAL_FLAGS) examples/hello_world.cr -o $(BIN) --link-flags="$(LDFLAGS)"
	crystal build $(CRYSTAL_FLAGS) examples/listbox_example.cr -o $(BIN_LB) --link-flags="$(LDFLAGS)"
	crystal build $(CRYSTAL_FLAGS) examples/checkbox_example.cr -o $(BIN_CB) --link-flags="$(LDFLAGS)"
	crystal build $(CRYSTAL_FLAGS) examples/radiobutton_example.cr -o $(BIN_RB) --link-flags="$(LDFLAGS)"
	crystal build $(CRYSTAL_FLAGS) examples/combobox_example.cr -o $(BIN_COMBO) --link-flags="$(LDFLAGS)"
	crystal build $(CRYSTAL_FLAGS) examples/openfiledialog_example.cr -o $(BIN_OFD) --link-flags="$(LDFLAGS)"
	crystal build $(CRYSTAL_FLAGS) examples/savefiledialog_example.cr -o $(BIN_SFD) --link-flags="$(LDFLAGS)"

spec: $(OBJ)  ## Run the crystal spec test suite
	crystal spec $(CRYSTAL_FLAGS) --link-flags="$(LDFLAGS)"

# ── Clean ──────────────────────────────────────────────────────────────

clean:  ## Remove build artifacts
	rm -f $(OBJ_all)
	rm -rf bin/

# ── Help ───────────────────────────────────────────────────────────────

help:  ## Show this help
	@echo "Quartz GUI toolkit — build system"
	@echo ""
	@echo "Usage:"
	@echo "  make [mac|gtk|qt|win]  Build the platform backend"
	@echo "  make examples           Build the hello_world example"
	@echo "  make clean              Remove build artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  BACKEND=gtk|qt|mac|win  Override auto-detected backend"
	@echo "  QT_VERSION=5|6          Select Qt version"
	@echo ""
	@echo "Current: BACKEND=$(BACKEND)  QT_VERSION=$(QT_VERSION)"
	@echo "  make clean             Remove all build artifacts"
	@echo ""
	@echo "Current auto-detected backend: $(BACKEND)"
	@echo ""
	@echo "For Qt 6:  make qt QT_VERSION=6"
