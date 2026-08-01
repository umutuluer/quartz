require "../src/quartz"

Quartz::Application.run do |app|
  window = Quartz::Window.new("Quartz — Merhaba Dünya", 400, 250)

  label = Quartz::Label.new("Merhaba Dünya!", x: 20, y: 20, width: 360, height: 30)
  window.add_control(label)

  button = Quartz::Button.new("Tıkla", x: 20, y: 60, width: 120, height: 32)
  button.on_click do
    label.text = "Butona tıklandı! 🎉"
  end
  window.add_control(button)

  window.show
end
