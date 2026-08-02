require "../src/quartz"

Quartz::Application.run do |app|
  window = Quartz::Window.new("TextBox Demo", 500, 400)

  # --- Normal TextBox ---
  normal_label = Quartz::Label.new("İsim:", 20, 20, 60, 25)
  name_input = Quartz::TextBox.new("", 90, 20, 200, 25)
  name_input.placeholder = "Adınızı yazın..."
  name_input.max_length = 50

  # --- Password TextBox ---
  pass_label = Quartz::Label.new("Şifre:", 20, 60, 60, 25)
  pass_input = Quartz::TextBox.new("", 90, 60, 200, 25)
  pass_input.password_char = '*'
  pass_input.placeholder = "Şifrenizi yazın..."

  # --- Read-only TextBox ---
  readonly_label = Quartz::Label.new("Durum:", 20, 100, 60, 25)
  status_input = Quartz::TextBox.new("Bu alan salt okunur", 90, 100, 200, 25)
  status_input.read_only = true

  # --- TextChanged event demo ---
  output_label = Quartz::Label.new("Çıktı: ", 20, 160, 280, 25)
  name_input.on_text_changed do
    output_label.text = "Çıktı: #{name_input.text}"
  end

  # --- Add all controls to window ---
  window.add_control(normal_label)
  window.add_control(name_input)
  window.add_control(pass_label)
  window.add_control(pass_input)
  window.add_control(readonly_label)
  window.add_control(status_input)
  window.add_control(output_label)

  window.show
end
