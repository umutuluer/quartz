require "../spec_helper"

# Native widget bounds reader used by layout specs.
#
# Wraps `LibQuartz.quartz_widget_get_bounds`. The C helper writes
# the current bounds into four out-params; unknown/invalid handles are
# reported as all-zeroes by the backend.
module BoundsHelper
  def self.bounds(handle : Int32) : {x: Int32, y: Int32, w: Int32, h: Int32}
    x = uninitialized Int32
    y = uninitialized Int32
    w = uninitialized Int32
    h = uninitialized Int32
    LibQuartz.quartz_widget_get_bounds(handle, pointerof(x), pointerof(y), pointerof(w), pointerof(h))
    {x: x, y: y, w: w, h: h}
  end
end
