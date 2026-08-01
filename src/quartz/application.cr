require "./control"
require "./window"

module Quartz
  # Entry point for every Quartz application.
  #
  # ```
  # Quartz::Application.run do
  #   window = Quartz::Window.new("My App", 800, 600)
  #   # ... add controls ...
  #   window.show
  # end
  # ```
  class Application
    @main_window : Window?

    def self.run(&block : Application ->)
      LibQuartz.quartz_init
      app = new
      yield app
      LibQuartz.quartz_run
    end

    def self.exit
      LibQuartz.quartz_terminate
    end
  end
end
