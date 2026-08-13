require "../src/quartz"

Quartz::Application.run do |app|
  window = Quartz::Window.new("ComboBox Demo", 400, 250)

  # --- Read-only ComboBox ---
  city_label = Quartz::Label.new("Şehir seçin:", 20, 20, 110, 25)
  city_combo = Quartz::ComboBox.new(130, 20, 230, 25)
  city_combo.add_item("İstanbul")
  city_combo.add_item("Ankara")
  city_combo.add_item("İzmir")
  city_combo.add_item("Bursa")

  # --- Selection label ---
  selection_label = Quartz::Label.new("Seçili: (yok)", 20, 60, 360, 25)

  # --- Editable ComboBox ---
  color_label = Quartz::Label.new("Renk yazın:", 20, 110, 110, 25)
  color_combo = Quartz::ComboBox.new(130, 110, 230, 25, editable: true)
  color_combo.add_item("Kırmızı")
  color_combo.add_item("Yeşil")
  color_combo.add_item("Mavi")

  # --- Text label ---
  text_label = Quartz::Label.new("Metin: (yok)", 20, 150, 360, 25)

  # --- Event handlers ---
  city_combo.on_selection_changed do
    if text = city_combo.selected_text
      selection_label.text = "Seçili: #{text}"
    else
      selection_label.text = "Seçili: (yok)"
    end
  end

  color_combo.on_text_changed do
    text_label.text = "Metin: #{color_combo.text}"
  end

  # --- Add all controls to window ---
  window.add_control(city_label)
  window.add_control(city_combo)
  window.add_control(selection_label)
  window.add_control(color_label)
  window.add_control(color_combo)
  window.add_control(text_label)

  window.show
end
