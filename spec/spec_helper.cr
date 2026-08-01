require "spec"
require "../src/quartz"

# Shared support modules (factories, matchers, etc.).
# `require` needs string literals at compile time, so list them
# explicitly here instead of globbing at runtime.
require "./support/widget_factory"

# Initialize the native GUI toolkit once for the entire test suite.
# Most backends (Qt, GTK, AppKit) must be initialized before any
# widget can be created. Calling quartz_init multiple times is
# harmless on all supported backends — they early-return if already
# initialised (see ext/quartz_helper_*.c).
LibQuartz.quartz_init
