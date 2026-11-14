-- Custom Glassy: Omarchy's Glassy window mode (toggles/window-glassy.lua) with
-- the opacity and blur values from glassy-values.lua, tuned live by
-- `glassy-tune`. Loaded after default.hypr.toggles so these values win, and
-- only while Glassy is the chosen mode (Appearance > Windows > Window Opacity,
-- or `omarchy hyprland window transparency glassy`).

local paths = require("default.hypr.paths")

local glassy = io.open(paths.state_home .. "/omarchy/toggles/hypr/window-glassy.lua", "r")
if not glassy then
  return
end
glassy:close()

local ok, v = pcall(dofile, paths.home .. "/.config/hypr/glassy-values.lua")
if not ok or type(v) ~= "table" then
  return
end

o.window(".*", { opacity = string.format("%.2f %.2f", v.opacity_active, v.opacity_inactive) })

-- Per-app looks from glassy-tune: transparent keeps the glassy opacity with no
-- blur behind it; opaque makes the app solid. Apps not listed keep the blur.
local list = io.open(paths.home .. "/.config/hypr/glassy-apps.list", "r")
if list then
  for line in list:lines() do
    local class, look = line:match("^%s*([^#%s][^%s]*)%s+(%a+)")
    if class then
      local match = "^" .. class:gsub("([%.%-%+%*%?%[%]%^%$%(%)])", "\\%1") .. "$"
      if look == "transparent" then
        o.window(match, { no_blur = true })
      elseif look == "opaque" then
        o.window(match, { opacity = "1.0 override 1.0 override", no_blur = true })
      end
    end
  end
  list:close()
end

-- Same guard as default/hypr/glass.lua: blur costs every frame on CPU rendering.
if o.software_rendering_defaults() then
  return
end

hl.config({
  decoration = {
    blur = {
      size = v.blur_size,
      passes = v.blur_passes,
      brightness = v.blur_brightness,
      contrast = v.blur_contrast,
      vibrancy = v.blur_vibrancy,
      vibrancy_darkness = v.blur_vibrancy_darkness,
      noise = v.blur_noise,
    },
  },
})
