require "../src/quartz"

Quartz::Application.run do |app|
  window = Quartz::Window.new("Menu Demo", 400, 250)
  label = Quartz::Label.new("No menu action yet", x: 20, y: 20, width: 360, height: 30)
  window.add_control(label)

  # Menubar
  bar = Quartz::MenuBar.new
  file = Quartz::MenuItem.new("File")
  quit = Quartz::MenuItem.new("Quit")
  quit.on_click { label.text = "Quit clicked!"; Quartz::Application.exit }
  bar.add_item(file).add_item(quit).add_separator

  window.menu_bar = bar

  # Context menu (sağ tıkla açılır)
  ctx = Quartz::ContextMenu.new
  ctx.add_item("Copy") { label.text = "Copy clicked" }
  ctx.add_item("Paste") { label.text = "Paste clicked" }
  window.context_menu = ctx

  # Editable textbox with context menu
  tb = Quartz::TextBox.new("", 20, 70, 360, 32)
  tb.context_menu = ctx # shared context menu

  window.add_control(tb)
  window.show
end
