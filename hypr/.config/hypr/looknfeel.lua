-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return "" end
  local content = f:read("*a") or ""
  f:close()
  return content:gsub("%z", ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function is_apple_machine()
  -- Apple Silicon MacBooks (M1/M2/M3) have devicetree model (e.g. Apple MacBook Air (M1, 2020))
  local dt_model = read_file("/proc/device-tree/model"):lower()
  if dt_model:find("macbook") or dt_model:find("apple") then
    return true
  end

  -- Intel MacBooks have DMI product_name or sys_vendor
  local dmi_product = read_file("/sys/class/dmi/id/product_name"):lower()
  local dmi_vendor = read_file("/sys/class/dmi/id/sys_vendor"):lower()
  if dmi_product:find("macbook") or dmi_vendor:find("apple") then
    return true
  end

  return false
end

-- Automatic gap adjustment per machine:
-- MacBook (Retina / HiDPI) -> standard 10px top gap
-- Dell Inspiron (1366x768 / standard display) -> 0px top gap under the status bar
local top_gap = is_apple_machine() and 10 or 0

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
hl.config({
  general = {
    gaps_out = { top = top_gap, right = 10, bottom = 10, left = 10 },
  },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
hl.config({
  decoration = {
    -- Use round window corners.
    rounding = 8,

    -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
    -- dim_inactive = true,
    -- dim_strength = 0.15,
  },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })
