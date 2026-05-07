-- Main CET window shell: tab bar, in-memory per-tab sizes (entSpawner baseUI pattern, simplified).
local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local style = dofile(this_dir() .. "cet_style.lua")

-- Keep in sync with `cyber_builder.version()` in init.lua.
local APP_VERSION = "0.1.0"

local base_ui = {
  activeTab = 1,
  loadTabSize = true,
  tabSizes = {},
  APP_VERSION = APP_VERSION,
}

local tabs = {
  {
    id = "catalog",
    name = "Catalog",
    defaultSize = { 720, 900 },
  },
  {
    id = "diagnostics",
    name = "Diagnostics",
    defaultSize = { 640, 480 },
  },
}

local function ensure_tab_sizes()
  for _, tab in ipairs(tabs) do
    if base_ui.tabSizes[tab.id] == nil then
      base_ui.tabSizes[tab.id] = { tab.defaultSize[1], tab.defaultSize[2] }
    end
  end
end

--- Draw the main window. `ctx` must provide:
--- - `windowTitle` (optional): overrides default title
--- - `draw_catalog()`: ImGui content for Catalog tab
--- - `draw_diagnostics()`: ImGui content for Diagnostics tab
function base_ui.draw(ctx)
  if type(ImGui) ~= "table" then
    return
  end
  ctx = type(ctx) == "table" and ctx or {}
  local draw_catalog = ctx.draw_catalog
  local draw_diagnostics = ctx.draw_diagnostics
  if type(draw_catalog) ~= "function" or type(draw_diagnostics) ~= "function" then
    return
  end

  style.initialize()
  ensure_tab_sizes()

  local title = type(ctx.windowTitle) == "string" and ctx.windowTitle ~= "" and ctx.windowTitle
    or ("CyberBuilder " .. APP_VERSION)

  if base_ui.loadTabSize then
    local id = tabs[base_ui.activeTab].id
    local sz = base_ui.tabSizes[id]
    ImGui.SetNextWindowSize(sz[1], sz[2])
    base_ui.loadTabSize = false
  end

  local ok = ImGui.Begin(title, true)
  if not ok then
    return
  end

  local tab_id = tabs[base_ui.activeTab].id
  local x, y = ImGui.GetWindowSize()
  if x ~= base_ui.tabSizes[tab_id][1] or y ~= base_ui.tabSizes[tab_id][2] then
    base_ui.tabSizes[tab_id] = { math.min(x, 5000), math.min(y, 3500) }
  end

  local tab_bar_flags = 0
  if type(ImGuiTabItemFlags) == "table" and ImGuiTabItemFlags.NoTooltip ~= nil then
    tab_bar_flags = ImGuiTabItemFlags.NoTooltip
  end
  if ImGui.BeginTabBar("CyberBuilderTabBar", tab_bar_flags) then
    for key, tab in ipairs(tabs) do
      if ImGui.BeginTabItem(tab.name) then
        if base_ui.activeTab ~= key then
          base_ui.activeTab = key
          base_ui.loadTabSize = true
        end
        ImGui.Spacing()
        if key == 1 then
          draw_catalog()
        else
          draw_diagnostics()
        end
        ImGui.EndTabItem()
      end
    end
    ImGui.EndTabBar()
  end

  ImGui.End()
end

function base_ui.default_window_title()
  return "CyberBuilder " .. APP_VERSION
end

return base_ui
