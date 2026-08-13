require "../src/quartz"

Quartz::Application.run do |app|
  window = Quartz::Window.new("Layout Demo", 400, 250)

  # --- Üst toolbar: 3 button yatay ---
  load_btn = Quartz::Button.new("Load", 0, 0, 80, 30)
  save_btn = Quartz::Button.new("Save", 0, 0, 80, 30)
  exit_btn = Quartz::Button.new("Exit", 0, 0, 80, 30)
  window.add_control(load_btn)
  window.add_control(save_btn)
  window.add_control(exit_btn)

  toolbar = Quartz::StackLayout.new(
    orientation: Quartz::StackLayout::Orientation::Horizontal,
    padding: 8,
    spacing: 8
  )
  toolbar.add(load_btn, 80, 30).add(save_btn, 80, 30).add(exit_btn, 80, 30)

  # --- İçerik: 2 label dikey ---
  status_label = Quartz::Label.new("Ready", x: 0, y: 0, width: 360, height: 30)
  info_label = Quartz::Label.new("Layout Manager MVP", x: 0, y: 0, width: 360, height: 30)
  window.add_control(status_label)
  window.add_control(info_label)

  content = Quartz::StackLayout.new(
    orientation: Quartz::StackLayout::Orientation::Vertical,
    padding: 8,
    spacing: 8
  )
  content.add(status_label, 360, 30).add(info_label, 360, 30)

  toolbar.relayout
  content.relayout

  exit_btn.on_click do
    Quartz::Application.exit
  end

  window.show
end
