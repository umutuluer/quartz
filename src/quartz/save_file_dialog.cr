require "./file_dialog"
require "./lib_quartz"

module Quartz
  # A blocking modal dialog for choosing where to save a file.
  # (.NET WinForms SaveFileDialog)
  #
  # ```
  # dialog = Quartz::SaveFileDialog.new
  # dialog.file_name = "untitled.txt"
  # if path = dialog.show_dialog(window)
  #   puts "Kaydedilen: #{path}"
  # end
  # ```
  class SaveFileDialog < FileDialog
    property? overwrite_prompt : Bool = true

    def show_dialog(owner : Window? = nil) : String?
      owner_id = owner ? owner.handle : -1
      ptr = LibQuartz.quartz_save_file_dialog(
        title.empty? ? Pointer(UInt8).null : title.to_unsafe,
        filter.empty? ? Pointer(UInt8).null : filter.to_unsafe,
        initial_directory.empty? ? Pointer(UInt8).null : initial_directory.to_unsafe,
        default_ext.empty? ? Pointer(UInt8).null : default_ext.to_unsafe,
        file_name.empty? ? Pointer(UInt8).null : file_name.to_unsafe,
        overwrite_prompt? ? 1 : 0,
        owner_id
      )
      ptr.null? ? nil : String.new(ptr)
    end
  end
end
