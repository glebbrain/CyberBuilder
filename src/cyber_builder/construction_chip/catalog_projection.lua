local catalog_projection = {}

local function trim(s)
  if type(s) ~= "string" then
    return ""
  end
  return (s:match("^%s*(.-)%s*$") or "")
end

local function normalize_query(query)
  return trim(type(query) == "string" and query:lower() or "")
end

local function as_array(v)
  return type(v) == "table" and v or {}
end

local function has_hidden_tag(tags)
  for _, tag in ipairs(as_array(tags)) do
    if type(tag) == "string" then
      local t = tag:lower()
      if t == "hidden" or t == "internal" then
        return true
      end
    end
  end
  return false
end

local function item_matches_query(item, q)
  if q == "" then
    return true
  end
  local fields = {
    type(item.name) == "string" and item.name:lower() or "",
    type(item.objectId) == "string" and item.objectId:lower() or "",
    type(item.globalId) == "string" and item.globalId:lower() or "",
    type(item.category) == "string" and item.category:lower() or "",
    type(item.resourcePath) == "string" and item.resourcePath:lower() or "",
  }
  for _, field in ipairs(fields) do
    if field:find(q, 1, true) then
      return true
    end
  end
  for _, tag in ipairs(as_array(item.tags)) do
    if type(tag) == "string" and tag:lower():find(q, 1, true) then
      return true
    end
  end
  return false
end

function catalog_projection.project(authorized_entries, opts)
  if type(authorized_entries) ~= "table" then
    return nil, "authorized_entries must be an array table"
  end
  opts = type(opts) == "table" and opts or {}
  local category_filter = trim(opts.category)
  local query = normalize_query(opts.query)
  local include_hidden = opts.includeHidden == true

  local out = {}
  for _, entry in ipairs(authorized_entries) do
    if type(entry) == "table" and entry.authorized == true then
      local hidden = entry.hidden == true or entry.internal == true or has_hidden_tag(entry.tags)
      local category_ok = (category_filter == "") or (trim(entry.category) == category_filter)
      local query_ok = item_matches_query(entry, query)
      local visibility_ok = include_hidden or not hidden
      if category_ok and query_ok and visibility_ok then
        out[#out + 1] = {
          globalId = entry.globalId,
          packId = entry.packId,
          objectId = entry.objectId,
          name = entry.name,
          type = entry.type,
          category = entry.category,
          tags = as_array(entry.tags),
          resourcePath = entry.resourcePath,
          hidden = hidden,
        }
      end
    end
  end
  return out, nil
end

return catalog_projection
