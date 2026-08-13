require "spec"
require "../src/quartz"

# Shared support modules (factories, matchers, etc.).
# `require` needs string literals at compile time, so list them
# explicitly here instead of globbing at runtime.
require "./support/widget_factory"
require "./support/bounds_helper"

# Initialize the native GUI toolkit once for the entire test suite.
# Most backends (Qt, GTK, AppKit) must be initialized before any
# widget can be created. Calling quartz_init multiple times is
# harmless on all supported backends — they early-return if already
# initialised (see ext/quartz_helper_*.c).
LibQuartz.quartz_init

# ── Widget lifecycle ─────────────────────────────────────────────────
#
# Native widget handles are plain integer IDs allocated in C (see
# ext/quartz_helper_*.c). Each Crystal wrapper (Quartz::Button,
# Quartz::Window, ...) carries its handle; there is no Crystal-side
# registry and the wrapper objects have no finalizers, so nothing is
# explicitly freed during the suite. Handles simply accumulate — one
# fresh ID per widget created. This is harmless because every lookup
# (`_dispatch`, property access) is keyed by handle and handles are
# never reused within a run.
#
# Callback blocks are stored in *class-level* hashes (`@@_callbacks`
# on each widget type, e.g. Quartz::Button.@@_callbacks) keyed by
# handle. They are intentionally never cleared, so those hashes grow
# by one entry per registered callback over the run. That is safe:
# an entry can only ever reference the block the example registered
# for that handle, so stale entries never fire for another example's
# handles.
#
# Consequently, suite-wide cleanup is GC-driven rather than explicit
# per-example teardown. If a future phase needs real teardown
# (pruning callback hashes, freeing native widgets, resetting shared
# state), this hook is the single place to add it.
Spec.after_each { }
