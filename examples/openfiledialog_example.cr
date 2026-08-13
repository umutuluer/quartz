require "../src/quartz"

Quartz::Application.run do |app|
  window = Quartz::Window.new("OpenFileDialog Demo", 400, 200)
  label = Quartz::Label.new("No file selected", x: 20, y: 20, width: 360, height: 30)
  window.add_control(label)

  button = Quartz::Button.new("Open File...", x: 20, y: 70, width: 120, height: 32)
  button.on_click do
    dialog = Quartz::OpenFileDialog.new
    dialog.title = "Bir dosya seçin"
    dialog.filter = "Metin dosyaları (*.txt)|*.txt|Tüm dosyalar (*.*)|*.*"
    dialog.initial_directory = Dir.current
    result = dialog.show_dialog(window)
    if result
      label.text = "Selected: #{result}"
    else
      label.text = "Cancelled"
    end
  end
  window.add_control(button)

  window.show
end
