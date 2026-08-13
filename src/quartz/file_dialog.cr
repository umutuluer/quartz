require "./lib_quartz"

module Quartz
  # Abstract base for blocking modal file dialogs.
  #
  # Unlike controls, a file dialog has no widget handle — `show_dialog`
  # runs a native modal dialog and returns the selected path (or nil if
  # the user cancelled). Concrete classes: `OpenFileDialog`,
  # `SaveFileDialog`.
  abstract class FileDialog
    property title : String = ""
    property filter : String = ""
    property initial_directory : String = ""
    property file_name : String = ""
    property default_ext : String = ""

    abstract def show_dialog(owner : Window? = nil) : String?

    # String → LibC::Char* için yardımcı (pointer'lı çağrı için)
    private def to_unsafe(s : String) : Pointer(UInt8)
      s.to_unsafe
    end

    private def to_unsafe_or_null(s : String) : Pointer(UInt8)
      s.empty? ? Pointer(UInt8).null : s.to_unsafe
    end
  end
end
