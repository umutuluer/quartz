require "./file_dialog"
require "./lib_quartz"

module Quartz
  # A blocking modal dialog for choosing a file to open.
  # (.NET WinForms OpenFileDialog)
  #
  # ```
  # dialog = Quartz::OpenFileDialog.new
  # dialog.title = "Bir dosya seçin"
  # if path = dialog.show_dialog(window)
  #   puts "Seçilen: #{path}"
  # end
  # ```
  class OpenFileDialog < FileDialog
    property multiselect : Bool = false

    def show_dialog(owner : Window? = nil) : String?
      owner_id = owner ? owner.handle : -1
      ptr = LibQuartz.quartz_open_file_dialog(
        title.empty? ? Pointer(UInt8).null : title.to_unsafe,
        filter.empty? ? Pointer(UInt8).null : filter.to_unsafe,
        initial_directory.empty? ? Pointer(UInt8).null : initial_directory.to_unsafe,
        default_ext.empty? ? Pointer(UInt8).null : default_ext.to_unsafe,
        multiselect ? 1 : 0,
        owner_id
      )
      ptr.null? ? nil : String.new(ptr)
    end

    # Multiselect için tam dizi — MVP: ilk dosya yerine ilk dosya döndürülüyor (C sınırlaması).
    # İleride C tarafında ayrı fonksiyon gerekecek.
    def show_multi(owner : Window? = nil) : Array(String)?
      # Şu an için show_dialog ile aynı (sadece ilk dosya döner)
      single = show_dialog(owner)
      single.nil? ? nil : [single]
    end
  end
end
