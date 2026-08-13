# Quartz — a Windows Forms-inspired GUI toolkit for Crystal on macOS.
#
# Built on top of AppKit via a thin Objective-C helper (`ext/quartz_helper.m`).
#
# ## Quick start
#
# ```
# require "quartz"
#
# Quartz::Application.run do |app|
#   window = Quartz::Window.new("Hello", 400, 300)
#
#   label = Quartz::Label.new("Merhaba Dünya!", x: 20, y: 20, width: 200, height: 30)
#   window.add_control(label)
#
#   button = Quartz::Button.new("Tıkla", x: 20, y: 60, width: 100, height: 30)
#   button.on_click { label.text = "Butona tıklandı!" }
#   window.add_control(button)
#
#   window.show
# end
# ```
module Quartz
  VERSION = "0.1.0"
end

require "./quartz/lib_quartz"
require "./quartz/control"
require "./quartz/application"
require "./quartz/window"
require "./quartz/button"
require "./quartz/label"
require "./quartz/textbox"
require "./quartz/listbox"
require "./quartz/combo_box"
require "./quartz/check_box"
require "./quartz/radio_button"
