-- CET overlay: CyberBuilder catalog + diagnostics (entSpawner-style shell via base_ui / cet_style).
local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local path_utils = dofile(this_dir() .. "../path_utils.lua")
local style = dofile(this_dir() .. "cet_style.lua")
local base_ui = dofile(this_dir() .. "base_ui.lua")

local catalog_ui = {}

local function repo_root_from_ui()
  return path_utils.normalize(path_utils.join(this_dir(), "..", "..", ".."))
end

local function norm_text(v)
  if type(v) ~= "string" then
    return ""
  end
  return v:lower()
end

local function item_global_id(item)
  if type(item) ~= "table" then
    return ""
  end
  if type(item.globalId) == "string" and item.globalId ~= "" then
    return item.globalId
  end
  local pid = type(item.packId) == "string" and item.packId or ""
  local oid = type(item.objectId) == "string" and item.objectId or ""
  if pid ~= "" and oid ~= "" then
    return pid .. ":" .. oid
  end
  if type(item.id) == "string" and item.id ~= "" then
    return item.id
  end
  return ""
end

local function tags_search_blob(tags)
  if type(tags) ~= "table" then
    return ""
  end
  local out = {}
  for _, tag in ipairs(tags) do
    if type(tag) == "string" and tag ~= "" then
      out[#out + 1] = tag
    end
  end
  return table.concat(out, " ")
end

local function item_matches_search(item, query)
  if type(query) ~= "string" or query == "" then
    return true
  end
  local nq = norm_text(query)
  if nq == "" then
    return true
  end
  local blobs = {
    type(item.name) == "string" and item.name or "",
    type(item.id) == "string" and item.id or "",
    type(item.objectId) == "string" and item.objectId or "",
    type(item.packId) == "string" and item.packId or "",
    type(item.category) == "string" and item.category or "",
    type(item.type) == "string" and item.type or "",
    type(item.resourcePath) == "string" and item.resourcePath or "",
    type(item.globalId) == "string" and item.globalId or "",
    tags_search_blob(item.tags),
  }
  for _, b in ipairs(blobs) do
    if norm_text(b):find(nq, 1, true) then
      return true
    end
  end
  return false
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
    local a_key = norm_text(item_global_id(a))
    local b_key = norm_text(item_global_id(b))
    if a_key ~= b_key then
      return a_key < b_key
    end
    return false
  end)
  return out
end

local function filter_objects_by_search(objects, query)
  if type(objects) ~= "table" then
    return {}
  end
  local out = {}
  for _, item in ipairs(objects) do
    if item_matches_search(item, query) then
      out[#out + 1] = item
    end
  end
  return out
end

local function find_selected_object(items, selected_id)
  if type(selected_id) ~= "string" or selected_id == "" then
    return nil
  end
  for _, item in ipairs(type(items) == "table" and items or {}) do
    if type(item) == "table" and item_global_id(item) == selected_id then
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
    ui_log("INFO", "clipboard: resourcePath copied")
    return
  end
  ui_log("INFO", "resourcePath (no ImGui clipboard): " .. resource_path)
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

--- Console + `dist/cyberbuilder_ui.log` under repo root (relative to this file).
local function ui_log(level, message)
  local L = type(level) == "string" and level:upper() or "INFO"
  local msg = type(message) == "string" and message or tostring(message)
  print(string.format("[CyberBuilder] %s %s", L, msg))
  local path = path_utils.join(repo_root_from_ui(), "dist", "cyberbuilder_ui.log")
  local okd, _ = ensure_parent_dir(path)
  if not okd then
    return
  end
  local ts = os.date("!%Y-%m-%dT%H:%M:%SZ")
  local f = io.open(path, "ab")
  if f then
    f:write(string.format("%s %s %s\n", ts, L, msg))
    f:close()
  end
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
  local object_id = safe_name_part(item.objectId or item.id, "object")
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
  searchText = "",
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
  catalog_ui.state.searchText = ""
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

function catalog_ui.draw_catalog_panel()
  local st = catalog_ui.state
  local has_items = #st.items > 0

  style.mutedText("Browse authorized catalog entries only. Placement is via World Builder, not this overlay.")
  style.spacedSeparator()

  style.sectionHeaderStart("Search", "Filter objects in the selected category by name, ids, tags, path.")
  style.setNextItemWidth(320)
  if type(ImGui.InputTextWithHint) == "function" then
    st.searchText = ImGui.InputTextWithHint("##search", "Search...", st.searchText or "", 512)
  else
    st.searchText = ImGui.InputText("##search", st.searchText or "", 512)
  end
  style.sectionHeaderEnd()

  style.sectionHeaderStart("Categories")
  if not has_items then
    style.mutedText("Empty state: no packs loaded.")
  else
    for _, category in ipairs(st.categories) do
      local selected = st.selectedCategory == category
      if ImGui.Selectable(category, selected) then
        st.selectedCategory = category
        st.selectedObjectId = nil
      end
    end
  end
  style.sectionHeaderEnd()

  style.sectionHeaderStart("Objects")
  local objects = build_objects_for_category(st.items, st.selectedCategory)
  local filtered = filter_objects_by_search(objects, st.searchText)
  if not has_items then
    style.mutedText("Empty state: no packs loaded.")
  elseif not st.selectedCategory then
    style.mutedText("Empty state: no category selected.")
  elseif #objects == 0 then
    style.mutedText("Empty state: no objects in this category.")
  elseif #filtered == 0 then
    style.mutedText("Empty state: no search results.")
  else
    for _, item in ipairs(filtered) do
      local gid = item_global_id(item)
      local label = type(item.name) == "string" and item.name ~= "" and item.name or (gid ~= "" and gid or "<unnamed>")
      local selected = st.selectedObjectId == gid
      if ImGui.Selectable(label, selected) then
        st.selectedObjectId = gid
      end
    end
  end
  style.sectionHeaderEnd()

  style.sectionHeaderStart("Object details")
  local selected_item = find_selected_object(filtered, st.selectedObjectId)
  if selected_item then
    local name = type(selected_item.name) == "string" and selected_item.name or ""
    local pack_id = type(selected_item.packId) == "string" and selected_item.packId or ""
    local object_id = type(selected_item.objectId) == "string" and selected_item.objectId or ""
    local gid = item_global_id(selected_item)
    local obj_type = type(selected_item.type) == "string" and selected_item.type or ""
    local price = type(selected_item.price) == "number" and selected_item.price or 0
    local tags = format_tags(selected_item.tags)
    local resource_path = type(selected_item.resourcePath) == "string" and selected_item.resourcePath or ""
    if gid ~= "" then
      ImGui.Text("globalId: " .. gid)
    end
    ImGui.Text("name: " .. name)
    ImGui.Text("packId: " .. pack_id)
    if object_id ~= "" then
      ImGui.Text("objectId: " .. object_id)
    end
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
        ui_log("INFO", "exported selected resourcePath to: " .. tostring(result))
      else
        ui_log("ERROR", "selected export failed: " .. tostring(result))
      end
    end
  else
    style.mutedText("Select an object to see details.")
  end
  style.sectionHeaderEnd()
end

function catalog_ui.draw_diagnostics_panel()
  style.sectionHeaderStart("Validation errors", "Tail of dist/cyberbuilder_errors.log")
  local errors = read_latest_validation_errors(50)
  if #errors == 0 then
    style.mutedText("No validation errors found (or log missing).")
  else
    for _, line in ipairs(errors) do
      ImGui.Text(line)
    end
  end
  style.sectionHeaderEnd()
end

function catalog_ui.draw()
  if not catalog_ui.state.visible then
    return
  end
  if type(ImGui) ~= "table" then
    return
  end

  local title = string.format("CyberBuilder Catalog %s", base_ui.APP_VERSION)
  base_ui.draw({
    windowTitle = title,
    draw_catalog = catalog_ui.draw_catalog_panel,
    draw_diagnostics = catalog_ui.draw_diagnostics_panel,
  })
end

return catalog_ui
