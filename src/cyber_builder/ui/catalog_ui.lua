-- Minimal CET overlay placeholder for CyberBuilder catalog UI.
local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local path_utils = dofile(this_dir() .. "../path_utils.lua")

local catalog_ui = {}

local function norm_text(v)
  if type(v) ~= "string" then
    return ""
  end
  return v:lower()
end

local function build_categories(items)
  local seen = {}
  local out = {}
  for _, item in ipairs(type(items) == "table" and items or {}) do
    if type(item) == "table" and type(item.category) == "string" and item.category ~= "" then
      if not seen[item.category] then
        seen[item.category] = true
        out[#out + 1] = item.category
      end
    end
  end
  table.sort(out, function(a, b)
    local na = norm_text(a)
    local nb = norm_text(b)
    if na ~= nb then
      return na < nb
    end
    return a < b
  end)
  return out
end

local function build_objects_for_category(items, category)
  if type(category) ~= "string" or category == "" then
    return {}
  end
  local out = {}
  for _, item in ipairs(type(items) == "table" and items or {}) do
    if type(item) == "table" and item.category == category then
      out[#out + 1] = item
    end
  end
  table.sort(out, function(a, b)
    local a_name = norm_text(type(a.name) == "string" and a.name or "")
    local b_name = norm_text(type(b.name) == "string" and b.name or "")
    if a_name ~= b_name then
      return a_name < b_name
    end
    local a_id = norm_text(type(a.id) == "string" and a.id or "")
    local b_id = norm_text(type(b.id) == "string" and b.id or "")
    return a_id < b_id
  end)
  return out
end

local function find_selected_object(items, selected_id)
  if type(selected_id) ~= "string" or selected_id == "" then
    return nil
  end
  for _, item in ipairs(type(items) == "table" and items or {}) do
    if type(item) == "table" and item.id == selected_id then
      return item
    end
  end
  return nil
end

local function format_tags(tags)
  if type(tags) ~= "table" or #tags == 0 then
    return ""
  end
  local out = {}
  for _, tag in ipairs(tags) do
    if type(tag) == "string" and tag ~= "" then
      out[#out + 1] = tag
    end
  end
  return table.concat(out, ", ")
end

local function copy_or_log_resource_path(resource_path)
  if type(resource_path) ~= "string" or resource_path == "" then
    return
  end
  if type(ImGui) == "table" and type(ImGui.SetClipboardText) == "function" then
    ImGui.SetClipboardText(resource_path)
    return
  end
  print("[CyberBuilder] resourcePath: " .. resource_path)
end

local function ensure_parent_dir(file_path)
  local parent = file_path:match("^(.*)[/\\][^/\\]+$")
  if not parent or parent == "" then
    return true, nil
  end
  if package.config:sub(1, 1) == "\\" then
    local p = parent:gsub("/", "\\"):gsub('"', "")
    os.execute('cmd /c mkdir "' .. p .. '" 2>nul')
    return true, nil
  end
  local lfs_ok, lfs = pcall(require, "lfs")
  if not lfs_ok or not lfs or not lfs.mkdir then
    return false, "cannot create output directories (install LuaFileSystem or use Windows)"
  end
  local acc = nil
  for piece in parent:gmatch("[^/\\]+") do
    acc = acc and (acc .. "/" .. piece) or piece
    pcall(lfs.mkdir, acc)
  end
  return true, nil
end

local function safe_name_part(v, fallback)
  local text = type(v) == "string" and v or ""
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then
    return fallback
  end
  text = text:gsub("[^%w%-_%.]+", "_")
  if text == "" then
    return fallback
  end
  return text
end

local function export_selected_resource_path(item)
  if type(item) ~= "table" then
    return false, "no selected item"
  end
  local resource_path = type(item.resourcePath) == "string" and item.resourcePath:match("^%s*(.-)%s*$") or ""
  if resource_path == "" then
    return false, "selected item has empty resourcePath"
  end
  local pack_id = safe_name_part(item.packId, "pack")
  local object_id = safe_name_part(item.id, "object")
  local file_name = string.format("cyberbuilder_selected_%s_%s.txt", pack_id, object_id)
  local out_path = path_utils.join("dist", "worldbuilder", "selected", file_name)
  local okd, derr = ensure_parent_dir(out_path)
  if not okd then
    return false, derr
  end
  local f, ferr = io.open(out_path, "wb")
  if not f then
    return false, string.format("cannot write %q (%s)", out_path, ferr or "unknown")
  end
  f:write(path_utils.normalize(resource_path))
  f:write("\n")
  f:close()
  return true, out_path
end

local function read_latest_validation_errors(max_lines)
  local limit = type(max_lines) == "number" and max_lines or 5
  if limit < 1 then
    limit = 1
  end
  local path = path_utils.join("dist", "cyberbuilder_errors.log")
  local f = io.open(path, "rb")
  if not f then
    return {}
  end
  local body = f:read("*a") or ""
  f:close()
  if body == "" then
    return {}
  end
  local lines = {}
  for line in body:gmatch("([^\r\n]+)") do
    if line ~= "" then
      lines[#lines + 1] = line
    end
  end
  local total = #lines
  if total <= limit then
    return lines
  end
  local out = {}
  for i = total - limit + 1, total do
    out[#out + 1] = lines[i]
  end
  return out
end

catalog_ui.state = {
  visible = false,
  items = {},
  categories = {},
  selectedCategory = nil,
  selectedObjectId = nil,
}

function catalog_ui.open()
  catalog_ui.state.visible = true
end

function catalog_ui.close()
  catalog_ui.state.visible = false
end

function catalog_ui.toggle()
  catalog_ui.state.visible = not catalog_ui.state.visible
  return catalog_ui.state.visible
end

function catalog_ui.set_items(items)
  catalog_ui.state.items = type(items) == "table" and items or {}
  catalog_ui.state.categories = build_categories(catalog_ui.state.items)
  if catalog_ui.state.selectedCategory ~= nil then
    local still_exists = false
    for _, category in ipairs(catalog_ui.state.categories) do
      if category == catalog_ui.state.selectedCategory then
        still_exists = true
        break
      end
    end
    if not still_exists then
      catalog_ui.state.selectedCategory = nil
    end
  end
  catalog_ui.state.selectedObjectId = nil
end

function catalog_ui.draw()
  if not catalog_ui.state.visible then
    return
  end
  if type(ImGui) ~= "table" then
    return
  end

  local ok = ImGui.Begin("CyberBuilder Catalog", true)
  if ok then
    local has_items = #catalog_ui.state.items > 0
    ImGui.Text("WARNING: CyberBuilder v0.2 does not spawn objects; use World Builder for placement.")
    ImGui.Separator()
    ImGui.Text("Categories")
    ImGui.Separator()
    if not has_items then
      ImGui.Text("Empty state: no packs loaded.")
    else
      for _, category in ipairs(catalog_ui.state.categories) do
        local selected = catalog_ui.state.selectedCategory == category
        if ImGui.Selectable(category, selected) then
          catalog_ui.state.selectedCategory = category
          catalog_ui.state.selectedObjectId = nil
        end
      end
    end
    ImGui.Separator()
    ImGui.Text("Objects")
    ImGui.Separator()
    local objects = build_objects_for_category(catalog_ui.state.items, catalog_ui.state.selectedCategory)
    if not has_items then
      ImGui.Text("Empty state: no packs loaded.")
    elseif not catalog_ui.state.selectedCategory then
      ImGui.Text("Empty state: no category selected.")
    elseif #objects == 0 then
      ImGui.Text("Empty state: no search results.")
    else
      for _, item in ipairs(objects) do
        local label = type(item.name) == "string" and item.name ~= "" and item.name or (type(item.id) == "string" and item.id or "<unnamed>")
        local selected = catalog_ui.state.selectedObjectId == item.id
        if ImGui.Selectable(label, selected) then
          catalog_ui.state.selectedObjectId = item.id
        end
      end
    end
    ImGui.Separator()
    ImGui.Text("Object Details")
    ImGui.Separator()
    local selected_item = find_selected_object(objects, catalog_ui.state.selectedObjectId)
    if selected_item then
      local name = type(selected_item.name) == "string" and selected_item.name or ""
      local pack_id = type(selected_item.packId) == "string" and selected_item.packId or ""
      local obj_type = type(selected_item.type) == "string" and selected_item.type or ""
      local price = type(selected_item.price) == "number" and selected_item.price or 0
      local tags = format_tags(selected_item.tags)
      local resource_path = type(selected_item.resourcePath) == "string" and selected_item.resourcePath or ""
      ImGui.Text("name: " .. name)
      ImGui.Text("packId: " .. pack_id)
      ImGui.Text("type: " .. obj_type)
      ImGui.Text("price: " .. tostring(price))
      ImGui.Text("tags: " .. tags)
      ImGui.Text("resourcePath: " .. resource_path)
      if ImGui.Button("Copy resourcePath") then
        copy_or_log_resource_path(resource_path)
      end
      if ImGui.Button("Export selected to World Builder txt") then
        local ok_export, result = export_selected_resource_path(selected_item)
        if ok_export then
          print("[CyberBuilder] exported selected resourcePath to: " .. result)
        else
          print("[CyberBuilder] selected export failed: " .. tostring(result))
        end
      end
    end
    ImGui.Separator()
    ImGui.Text("Validation Errors")
    ImGui.Separator()
    local errors = read_latest_validation_errors(5)
    if #errors == 0 then
      ImGui.Text("No validation errors found.")
    else
      for _, line in ipairs(errors) do
        ImGui.Text(line)
      end
    end
  end
  ImGui.End()
end

return catalog_ui
