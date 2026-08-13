require "../src/quartz"

Quartz::Application.run do |app|
  window = Quartz::Window.new("CheckBox Demo", 450, 300)

  # --- CheckBoxes ---
  bold_check = Quartz::CheckBox.new("Kalın", 20, 20, 120, 25)
  italic_check = Quartz::CheckBox.new("İtalik", 20, 55, 120, 25)
  underline_check = Quartz::CheckBox.new("Altı Çizili", 20, 90, 120, 25)

  # --- Status label ---
  status_label = Quartz::Label.new("Hiçbir stil seçili değil", 20, 150, 400, 25)

  # --- Event handler — updates the status when any checkbox changes ---
  update_status = -> {
    styles = [] of String
    styles << "Kalın" if bold_check.checked
    styles << "İtalik" if italic_check.checked
    styles << "Altı Çizili" if underline_check.checked

    if styles.empty?
      status_label.text = "Hiçbir stil seçili değil"
    else
      status_label.text = "Seçili stiller: #{styles.join(", ")}"
    end
  }

  bold_check.on_checked_changed { update_status.call }
  italic_check.on_checked_changed { update_status.call }
  underline_check.on_checked_changed { update_status.call }

  # --- Add all controls to window ---
  window.add_control(bold_check)
  window.add_control(italic_check)
  window.add_control(underline_check)
  window.add_control(status_label)

  window.show
end
