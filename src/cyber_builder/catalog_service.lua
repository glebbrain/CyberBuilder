-- Catalog service: convert validated pack payloads into catalog DTO items.
local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local path_utils = dofile(this_dir() .. "path_utils.lua")
local catalog_model = dofile(this_dir() .. "catalog_model.lua")

local catalog_service = {}

local function as_array(v)
  return type(v) == "table" and v or {}
end

local function recipe_index(recipes)
  local idx = {}
  for _, rec in ipairs(as_array(recipes)) do
    if type(rec) == "table" and type(rec.objectId) == "string" then
      idx[rec.objectId] = rec
    end
  end
  return idx
end

--- Convert validated packs into normalized catalog items.
-- Each pack entry is expected as:
-- { pack = <pack.json table>, objects = <objects.json array>, recipes = <recipes.json array>, sourceFile = <string|nil> }
-- Optional `opts.showDisabled == true` includes disabled objects (debug mode only).
function catalog_service.from_validated_packs(validated_packs, opts)
  if type(validated_packs) ~= "table" then
    return nil, "validated_packs must be an array table"
  end
  opts = type(opts) == "table" and opts or {}
  local show_disabled = opts.showDisabled == true

  local out = {}
  for _, entry in ipairs(validated_packs) do
    if type(entry) == "table" then
      local pack = type(entry.pack) == "table" and entry.pack or {}
      local pack_id = type(pack.id) == "string" and pack.id or ""
      local recipes_by_object_id = recipe_index(entry.recipes)
      local source_file = type(entry.sourceFile) == "string" and entry.sourceFile or "objects.json"

      for _, obj in ipairs(as_array(entry.objects)) do
        if type(obj) == "table" and (show_disabled or obj.disabled ~= true) then
          local item, err = catalog_model.new_item({
            id = obj.id,
            packId = pack_id,
            name = obj.name,
            type = obj.type,
            category = obj.category,
            tags = obj.tags,
            price = obj.price,
            resourcePath = obj.resourcePath,
            recipe = recipes_by_object_id[obj.id],
            sourceFile = source_file,
          })
          if not item then
            return nil, err
          end
          out[#out + 1] = item
        end
      end
    end
  end
  return out, nil
end

--- Build category index: category -> list of catalog items.
function catalog_service.build_category_index(items)
  if type(items) ~= "table" then
    return nil, "items must be an array table"
  end
  local index = {}
  for _, item in ipairs(items) do
    if type(item) == "table" then
      local category = type(item.category) == "string" and item.category or ""
      if category ~= "" then
        if not index[category] then
          index[category] = {}
        end
        index[category][#index[category] + 1] = item
      end
    end
  end
  return index, nil
end

--- Build tag index: tag -> list of catalog items.
function catalog_service.build_tag_index(items)
  if type(items) ~= "table" then
    return nil, "items must be an array table"
  end
  local index = {}
  for _, item in ipairs(items) do
    if type(item) == "table" and type(item.tags) == "table" then
      for _, tag in ipairs(item.tags) do
        if type(tag) == "string" and tag ~= "" then
          if not index[tag] then
            index[tag] = {}
          end
          index[tag][#index[tag] + 1] = item
        end
      end
    end
  end
  return index, nil
end

local function norm_text(v)
  if type(v) ~= "string" then
    return ""
  end
  return v:lower()
end

local function json_escape(s)
  return s:gsub('[%z\1-\31\\"]', function(c)
    local map = {
      ['"'] = '\\"',
      ["\\"] = "\\\\",
      ["\b"] = "\\b",
      ["\f"] = "\\f",
      ["\n"] = "\\n",
      ["\r"] = "\\r",
      ["\t"] = "\\t",
    }
    return map[c] or string.format("\\u%04x", c:byte())
  end)
end

local function json_encode(v)
  local tv = type(v)
  if tv == "nil" then
    return "null"
  end
  if tv == "boolean" then
    return v and "true" or "false"
  end
  if tv == "number" then
    return string.format("%.14g", v)
  end
  if tv == "string" then
    return '"' .. json_escape(v) .. '"'
  end
  if tv ~= "table" then
    error("unsupported json type: " .. tv)
  end

  if #v > 0 then
    local arr = {}
    for i = 1, #v do
      arr[#arr + 1] = json_encode(v[i])
    end
    return "[" .. table.concat(arr, ",") .. "]"
  end

  local keys = {}
  for k in pairs(v) do
    if type(k) == "string" then
      keys[#keys + 1] = k
    end
  end
  table.sort(keys)
  local obj = {}
  for _, k in ipairs(keys) do
    obj[#obj + 1] = json_encode(k) .. ":" .. json_encode(v[k])
  end
  return "{" .. table.concat(obj, ",") .. "}"
end

local function item_matches_query(item, q)
  if type(item) ~= "table" then
    return false
  end
  if norm_text(item.name):find(q, 1, true) then
    return true
  end
  if norm_text(item.id):find(q, 1, true) then
    return true
  end
  if norm_text(item.category):find(q, 1, true) then
    return true
  end
  if norm_text(item.resourcePath):find(q, 1, true) then
    return true
  end
  if type(item.tags) == "table" then
    for _, tag in ipairs(item.tags) do
      if norm_text(tag):find(q, 1, true) then
        return true
      end
    end
  end
  return false
end

--- Search catalog items by substring match over name/id/tag/category/resourcePath.
function catalog_service.search(items, query)
  if type(items) ~= "table" then
    return nil, "items must be an array table"
  end
  local q = norm_text(query)
  if q == "" then
    return {}, nil
  end
  local out = {}
  for _, item in ipairs(items) do
    if item_matches_query(item, q) then
      out[#out + 1] = item
    end
  end
  return out, nil
end

--- Deterministic sort by category, name, id.
function catalog_service.sort_items(items)
  if type(items) ~= "table" then
    return nil, "items must be an array table"
  end
  local out = {}
  for i = 1, #items do
    out[i] = items[i]
  end
  table.sort(out, function(a, b)
    local a_category = norm_text(type(a) == "table" and a.category or "")
    local b_category = norm_text(type(b) == "table" and b.category or "")
    if a_category ~= b_category then
      return a_category < b_category
    end

    local a_name = norm_text(type(a) == "table" and a.name or "")
    local b_name = norm_text(type(b) == "table" and b.name or "")
    if a_name ~= b_name then
      return a_name < b_name
    end

    local a_id = norm_text(type(a) == "table" and a.id or "")
    local b_id = norm_text(type(b) == "table" and b.id or "")
    return a_id < b_id
  end)
  return out, nil
end

--- Export catalog snapshot to `<dist_dir>/cyberbuilder_catalog.json`.
function catalog_service.export_catalog_snapshot(items, dist_dir)
  if type(items) ~= "table" then
    return nil, "items must be an array table"
  end
  if type(dist_dir) ~= "string" or dist_dir == "" then
    return nil, "dist_dir must be a non-empty string"
  end

  local out_path = path_utils.join(dist_dir, "cyberbuilder_catalog.json")
  local parent = out_path:match("^(.*)[/\\][^/\\]+$")
  if parent and parent ~= "" and package.config:sub(1, 1) == "\\" then
    os.execute('cmd /c mkdir "' .. parent:gsub("/", "\\"):gsub('"', "") .. '" 2>nul')
  end

  local body = json_encode(items) .. "\n"
  local f, err = io.open(out_path, "wb")
  if not f then
    return nil, string.format("cannot write catalog snapshot %q (%s)", out_path, err or "unknown")
  end
  f:write(body)
  f:close()
  return out_path, nil
end

--- Write catalog summary to `<dist_dir>/cyberbuilder_export_summary.json`.
function catalog_service.export_catalog_summary(items, dist_dir)
  if type(items) ~= "table" then
    return nil, "items must be an array table"
  end
  if type(dist_dir) ~= "string" or dist_dir == "" then
    return nil, "dist_dir must be a non-empty string"
  end

  local category_index = catalog_service.build_category_index(items) or {}
  local tag_index = catalog_service.build_tag_index(items) or {}
  local category_count = 0
  for _ in pairs(category_index) do
    category_count = category_count + 1
  end
  local tag_count = 0
  for _ in pairs(tag_index) do
    tag_count = tag_count + 1
  end

  local summary = {
    catalogItems = #items,
    categories = category_count,
    tags = tag_count,
  }

  local out_path = path_utils.join(dist_dir, "cyberbuilder_export_summary.json")
  local parent = out_path:match("^(.*)[/\\][^/\\]+$")
  if parent and parent ~= "" and package.config:sub(1, 1) == "\\" then
    os.execute('cmd /c mkdir "' .. parent:gsub("/", "\\"):gsub('"', "") .. '" 2>nul')
  end

  local body = json_encode(summary) .. "\n"
  local f, err = io.open(out_path, "wb")
  if not f then
    return nil, string.format("cannot write catalog summary %q (%s)", out_path, err or "unknown")
  end
  f:write(body)
  f:close()
  return out_path, nil
end

--- Validate that catalog has no duplicate global ids `packId:objectId`.
function catalog_service.validate_no_duplicate_global_ids(items)
  if type(items) ~= "table" then
    return nil, "items must be an array table"
  end
  local seen = {}
  for i, item in ipairs(items) do
    if type(item) == "table" then
      local pack_id = type(item.packId) == "string" and item.packId or ""
      local object_id = type(item.id) == "string" and item.id or ""
      local global_id = pack_id .. ":" .. object_id
      if seen[global_id] then
        return false, string.format(
          "duplicate global catalog id %q (first at index %d, duplicate at index %d)",
          global_id,
          seen[global_id],
          i
        )
      end
      seen[global_id] = i
    end
  end
  return true, nil
end

--- Validate that every catalog item price is >= 0.
function catalog_service.validate_non_negative_prices(items)
  if type(items) ~= "table" then
    return nil, "items must be an array table"
  end
  for i, item in ipairs(items) do
    if type(item) == "table" then
      local price = item.price
      if type(price) ~= "number" then
        return false, string.format("catalog item at index %d has non-numeric price", i)
      end
      if price < 0 then
        return false, string.format("catalog item at index %d has negative price (%s)", i, tostring(price))
      end
    end
  end
  return true, nil
end

--- Validate tags are an array of lowercase strings.
function catalog_service.validate_lowercase_tags(items)
  if type(items) ~= "table" then
    return nil, "items must be an array table"
  end
  for i, item in ipairs(items) do
    if type(item) == "table" then
      if type(item.tags) ~= "table" then
        return false, string.format("catalog item at index %d has non-array tags", i)
      end
      for j, tag in ipairs(item.tags) do
        if type(tag) ~= "string" then
          return false, string.format("catalog item at index %d has non-string tag at tags[%d]", i, j)
        end
        if tag ~= tag:lower() then
          return false, string.format("catalog item at index %d has non-lowercase tag %q", i, tag)
        end
      end
    end
  end
  return true, nil
end

--- Validate category is a non-empty string.
function catalog_service.validate_non_empty_category(items)
  if type(items) ~= "table" then
    return nil, "items must be an array table"
  end
  for i, item in ipairs(items) do
    if type(item) == "table" then
      if type(item.category) ~= "string" then
        return false, string.format("catalog item at index %d has non-string category", i)
      end
      if item.category:find("%S") == nil then
        return false, string.format("catalog item at index %d has empty category", i)
      end
    end
  end
  return true, nil
end

return catalog_service
