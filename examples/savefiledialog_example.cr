require "../src/quartz"

Quartz::Application.run do |app|
  window = Quartz::Window.new("SaveFileDialog Demo", 400, 200)
  label = Quartz::Label.new("Save your work", x: 20, y: 20, width: 360, height: 30)
  window.add_control(label)

  button = Quartz::Button.new("Save As...", x: 20, y: 70, width: 120, height: 32)
  button.on_click do
    dialog = Quartz::SaveFileDialog.new
    dialog.title = "Dosyayı kaydet"
    dialog.filter = "Metin dosyaları (*.txt)|*.txt|Tüm dosyalar (*.*)|*.*"
    dialog.default_ext = "txt"
    dialog.file_name = "untitled.txt"
    dialog.initial_directory = Dir.current
    dialog.overwrite_prompt = true
    result = dialog.show_dialog(window)
    if result
      label.text = "Saved: #{result}"
    else
      label.text = "Cancelled"
    end
  end
  window.add_control(button)

  window.show
end
