require "../src/quartz"

Quartz::Application.run do |app|
  window = Quartz::Window.new("ListBox Demo", 500, 400)

  # --- Value label ---
  value_label = Quartz::Label.new("Değer:", 20, 20, 60, 25)

  # --- TextBox for input ---
  input = Quartz::TextBox.new("", 90, 20, 170, 25)
  input.placeholder = "Bir değer girin..."

  # --- "Ekle" button ---
  add_button = Quartz::Button.new("Ekle", 270, 20, 65, 30)

  # --- "Çıkar" button (initially disabled) ---
  remove_button = Quartz::Button.new("Çıkar", 340, 20, 65, 30)
  remove_button.enabled = false

  # --- "Temizle" button ---
  clear_button = Quartz::Button.new("Temizle", 410, 20, 70, 30)

  # --- ListBox ---
  listbox = Quartz::ListBox.new(20, 60, 460, 250)

  # --- Selection label ---
  selection_label = Quartz::Label.new("Seçili: (yok)", 20, 320, 460, 25)

  # --- Event handlers ---
  add_button.on_click do
    text = input.text.strip
    unless text.empty?
      listbox.add_item(text)
      input.text = ""
    end
  end

  remove_button.on_click do
    index = listbox.selected_index
    if index >= 0
      listbox.remove_item(index)
      selection_label.text = "Seçili: (yok)"
    end
  end

  clear_button.on_click do
    listbox.clear
    selection_label.text = "Seçili: (yok)"
    remove_button.enabled = false
  end

  listbox.on_selection_changed do
    if text = listbox.selected_text
      selection_label.text = "Seçili: #{text}"
      remove_button.enabled = true
    else
      selection_label.text = "Seçili: (yok)"
      remove_button.enabled = false
    end
  end

  # --- Add all controls to window ---
  window.add_control(value_label)
  window.add_control(input)
  window.add_control(add_button)
  window.add_control(remove_button)
  window.add_control(clear_button)
  window.add_control(listbox)
  window.add_control(selection_label)

  window.show
end
