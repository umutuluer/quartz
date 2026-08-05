require "../src/quartz"

Quartz::Application.run do |app|
  window = Quartz::Window.new("RadioButton Demo", 450, 300)

  # --- RadioButton group — platform selection ---
  platform_label = Quartz::Label.new("Platform seçin:", 20, 20, 200, 25)

  mac_radio = Quartz::RadioButton.new("macOS", 20, 55, 120, 25, checked: true)
  linux_radio = Quartz::RadioButton.new("Linux", 20, 90, 120, 25)
  windows_radio = Quartz::RadioButton.new("Windows", 20, 125, 120, 25)

  # --- Currently selected platform display ---
  selection_label = Quartz::Label.new("Seçili: macOS", 20, 180, 400, 25)

  # --- Event handlers — update the label when any radio changes ---
  on_platform_change = ->{
    selected = if mac_radio.checked
                 "macOS"
               elsif linux_radio.checked
                 "Linux"
               elsif windows_radio.checked
                 "Windows"
               else
                 "(hiçbiri)"
               end
    selection_label.text = "Seçili: #{selected}"
  }

  mac_radio.on_checked_changed { on_platform_change.call }
  linux_radio.on_checked_changed { on_platform_change.call }
  windows_radio.on_checked_changed { on_platform_change.call }

  # --- Add all controls to window ---
  window.add_control(platform_label)
  window.add_control(mac_radio)
  window.add_control(linux_radio)
  window.add_control(windows_radio)
  window.add_control(selection_label)

  window.show
end
