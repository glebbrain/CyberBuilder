-- Catalog model DTO helpers.
-- This module only defines a normalized DTO container.
local catalog_model = {}

local function trim_string(value)
  if type(value) ~= "string" then
    return value
  end
  return value:match("^%s*(.-)%s*$")
end

local function normalize_value(value)
  local kind = type(value)
  if kind == "string" then
    return trim_string(value)
  end
  if kind ~= "table" then
    return value
  end

  local out = {}
  local is_array = (#value > 0)
  if is_array then
    for i = 1, #value do
      out[i] = normalize_value(value[i])
    end
    return out
  end

  for k, v in pairs(value) do
    out[k] = normalize_value(v)
  end
  return out
end

local function to_number_or_default(v, fallback)
  if type(v) == "number" then
    return v
  end
  if type(v) == "string" then
    local n = tonumber(v)
    if n ~= nil then
      return n
    end
  end
  return fallback
end

local function to_string_array(v)
  if type(v) ~= "table" then
    return {}
  end
  local out = {}
  for i = 1, #v do
    if type(v[i]) == "string" then
      out[#out + 1] = trim_string(v[i])
    end
  end
  return out
end

--- Build normalized DTO payload from any table-like source.
-- Returns `dto, nil` on success; `nil, err` on invalid input.
function catalog_model.new(raw)
  if type(raw) ~= "table" then
    return nil, "catalog dto source must be a table"
  end
  return normalize_value(raw), nil
end

--- Build normalized catalog item DTO with canonical fields.
function catalog_model.new_item(raw)
  if type(raw) ~= "table" then
    return nil, "catalog item source must be a table"
  end
  local dto = {
    id = trim_string(raw.id or ""),
    packId = trim_string(raw.packId or ""),
    name = trim_string(raw.name or ""),
    type = trim_string(raw.type or ""),
    category = trim_string(raw.category or ""),
    tags = to_string_array(raw.tags),
    price = to_number_or_default(raw.price, 0),
    resourcePath = trim_string(raw.resourcePath or ""),
    recipe = normalize_value(raw.recipe),
    sourceFile = trim_string(raw.sourceFile or ""),
  }
  return dto, nil
end

return catalog_model
