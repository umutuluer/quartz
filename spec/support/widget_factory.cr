require "../spec_helper"

# Shared factory helpers for unit specs. The native toolkit is already
# initialised by spec_helper.cr, so these can be called directly.
module WidgetFactory
  DEFAULT_GEOMETRY = {0, 0, 100, 30}

  def self.button(text = "Test", x = 0, y = 0, width = 100, height = 30)
    Quartz::Button.new(text, x, y, width, height)
  end

  def self.label(text = "Test", x = 0, y = 0, width = 100, height = 30)
    Quartz::Label.new(text, x, y, width, height)
  end

  def self.textbox(text = "Test", x = 0, y = 0, width = 120, height = 25)
    Quartz::TextBox.new(text, x, y, width, height)
  end

  def self.window(title = "Test Window", width = 400, height = 300)
    Quartz::Window.new(title, width, height)
  end

  def self.listbox(x = 0, y = 0, width = 150, height = 100)
    Quartz::ListBox.new(x, y, width, height)
  end
end
