local placement_id_generator = {}

local function normalize_text(v)
  if type(v) ~= "string" then
    return ""
  end
  local s = (v:match("^%s*(.-)%s*$") or ""):lower()
  s = s:gsub("%s+", "_")
  s = s:gsub("[^a-z0-9_%-:]", "")
  return s
end

local function compose_seed(fields)
  local parts = {}
  for _, value in ipairs(fields) do
    parts[#parts + 1] = normalize_text(value)
  end
  return table.concat(parts, "|")
end

-- FNV-1a 32-bit hash for deterministic id generation.
local function fnv1a_32(input)
  local hash = 2166136261
  for i = 1, #input do
    hash = hash ~ input:byte(i)
    hash = (hash * 16777619) % 4294967296
  end
  return string.format("%08x", hash)
end

-- Deterministically generate placement id from stable request fields.
-- Returns `placementId, nil` or `nil, "error"`.
function placement_id_generator.generate(request)
  if type(request) ~= "table" then
    return nil, "request must be a table"
  end

  local owner_id = request.ownerId
  local pack_id = request.packId
  local object_id = request.objectId
  local provider = request.provider

  if type(owner_id) ~= "string" or owner_id:find("%S") == nil then
    return nil, "request.ownerId must be a non-empty string"
  end
  if type(pack_id) ~= "string" or pack_id:find("%S") == nil then
    return nil, "request.packId must be a non-empty string"
  end
  if type(object_id) ~= "string" or object_id:find("%S") == nil then
    return nil, "request.objectId must be a non-empty string"
  end
  if type(provider) ~= "string" or provider:find("%S") == nil then
    return nil, "request.provider must be a non-empty string"
  end

  local transform = request.transform or {}
  local position = type(transform.position) == "table" and transform.position or {}
  local rotation = type(transform.rotation) == "table" and transform.rotation or {}
  local scale = transform.scale

  local seed = compose_seed({
    owner_id,
    pack_id,
    object_id,
    provider,
    tostring(position.x),
    tostring(position.y),
    tostring(position.z),
    tostring(rotation.pitch),
    tostring(rotation.yaw),
    tostring(rotation.roll),
    tostring(scale),
  })

  return "plc_" .. fnv1a_32(seed), nil
end

return placement_id_generator
