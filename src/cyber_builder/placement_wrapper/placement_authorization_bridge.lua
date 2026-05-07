local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local sep = package.config:sub(1, 1)
local build_authorizer = dofile(this_dir() .. ".." .. sep .. "construction_chip" .. sep .. "build_authorizer.lua")

local placement_authorization_bridge = {}

local function normalize_id(v)
  if type(v) ~= "string" then
    return ""
  end
  return (v:match("^%s*(.-)%s*$") or "")
end

local function make_global_id(pack_id, object_id)
  local p = normalize_id(pack_id)
  local o = normalize_id(object_id)
  if p == "" or o == "" then
    return ""
  end
  return p .. ":" .. o
end

local function parse_epoch_seconds(value)
  if type(value) == "number" then
    return value
  end
  if type(value) ~= "string" then
    return nil
  end
  local as_num = tonumber(value)
  if as_num ~= nil then
    return as_num
  end
  local year, month, day, hour, min, sec = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)Z$")
  if not year then
    return nil
  end
  return os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec),
    isdst = false,
  })
end

local function has_tag(tags, expected)
  if type(tags) ~= "table" then
    return false
  end
  for _, tag in ipairs(tags) do
    if type(tag) == "string" and normalize_id(tag):lower() == expected then
      return true
    end
  end
  return false
end

local function is_hidden_or_internal_entry(entry)
  if type(entry) ~= "table" then
    return false
  end
  if entry.hidden == true or entry.internal == true then
    return true
  end
  if has_tag(entry.tags, "hidden") or has_tag(entry.tags, "internal") then
    return true
  end
  return false
end

local function index_authorized_entries(authorized_entries)
  local by_global_id = {}
  local by_pair = {}
  for _, entry in ipairs(authorized_entries) do
    if type(entry) == "table" and not is_hidden_or_internal_entry(entry) then
      local global_id = normalize_id(entry.globalId)
      local pair_key = make_global_id(entry.packId, entry.objectId)
      if global_id ~= "" then
        by_global_id[global_id] = entry
      end
      if pair_key ~= "" then
        by_pair[pair_key] = entry
      end
    end
  end
  return by_global_id, by_pair
end

function placement_authorization_bridge.from_validated_packs(validated_packs)
  local authorized_entries, err = build_authorizer.generate_from_valid_packs(validated_packs)
  if not authorized_entries then
    return nil, err
  end
  local filtered_entries = {}
  for _, entry in ipairs(authorized_entries) do
    if type(entry) == "table" and not is_hidden_or_internal_entry(entry) then
      filtered_entries[#filtered_entries + 1] = entry
    end
  end
  local by_global_id, by_pair = index_authorized_entries(filtered_entries)
  return {
    entries = filtered_entries,
    byGlobalId = by_global_id,
    byPair = by_pair,
  }, nil
end

function placement_authorization_bridge.resolve_entry(authorization_index, pack_id, object_id, global_id)
  if type(authorization_index) ~= "table" then
    return nil, "authorization_index must be a table"
  end
  local by_global_id = type(authorization_index.byGlobalId) == "table" and authorization_index.byGlobalId or {}
  local by_pair = type(authorization_index.byPair) == "table" and authorization_index.byPair or {}

  local normalized_global_id = normalize_id(global_id)
  if normalized_global_id ~= "" and by_global_id[normalized_global_id] then
    return by_global_id[normalized_global_id], nil
  end

  local pair_key = make_global_id(pack_id, object_id)
  if pair_key ~= "" and by_pair[pair_key] then
    return by_pair[pair_key], nil
  end

  return nil, "object is not authorized by Construction Chip"
end

function placement_authorization_bridge.create_authorized_request(authorization_index, request)
  if type(request) ~= "table" then
    return nil, "request must be a table"
  end

  local entry, err = placement_authorization_bridge.resolve_entry(
    authorization_index,
    request.packId,
    request.objectId,
    request.globalId
  )
  if not entry then
    return nil, err
  end

  local normalized = {}
  for k, v in pairs(request) do
    normalized[k] = v
  end
  normalized.packId = entry.packId
  normalized.objectId = entry.objectId
  normalized.globalId = entry.globalId
  normalized.authorized = true
  return normalized, nil
end

-- Generate a placement request using only a Construction Chip-authorized entry.
-- `request_seed` may provide additional fields (requestId, sessionId, ownerId, provider, transform, tags, requestedAt).
-- Returns `request, nil` or `nil, "error"`.
function placement_authorization_bridge.generate_request_from_authorized_entry(entry, request_seed)
  if type(entry) ~= "table" then
    return nil, "authorized entry must be a table"
  end
  local pack_id = normalize_id(entry.packId)
  local object_id = normalize_id(entry.objectId)
  local global_id = normalize_id(entry.globalId)
  if pack_id == "" or object_id == "" or global_id == "" then
    return nil, "authorized entry must include packId, objectId, and globalId"
  end

  local seed = type(request_seed) == "table" and request_seed or {}
  local request = {}
  for k, v in pairs(seed) do
    request[k] = v
  end

  -- Force identity fields to come from authorized entry only.
  request.packId = pack_id
  request.objectId = object_id
  request.globalId = global_id
  request.authorized = true
  return request, nil
end

-- Resolve authorized object first, then generate placement request.
-- Returns `request, nil` or `nil, "error"`.
function placement_authorization_bridge.generate_request_from_authorized_object(
  authorization_index,
  pack_id,
  object_id,
  global_id,
  request_seed
)
  local entry, err = placement_authorization_bridge.resolve_entry(authorization_index, pack_id, object_id, global_id)
  if not entry then
    return nil, err
  end
  return placement_authorization_bridge.generate_request_from_authorized_entry(entry, request_seed)
end

-- Validate authorization entry freshness using issued/authorized timestamp and max age.
-- Returns `true, nil` or `false, "error"`.
function placement_authorization_bridge.validate_authorization_freshness(entry, now_epoch_seconds, max_age_seconds)
  if type(entry) ~= "table" then
    return false, "authorization entry must be a table"
  end

  local now_value = tonumber(now_epoch_seconds)
  if now_value == nil then
    return false, "now_epoch_seconds must be a number"
  end
  local max_age = tonumber(max_age_seconds)
  if max_age == nil or max_age < 0 then
    return false, "max_age_seconds must be a non-negative number"
  end

  local issued_at = entry.authorizedAt or entry.issuedAt or entry.createdAt
  local issued_epoch = parse_epoch_seconds(issued_at)
  if issued_epoch == nil then
    return false, "authorization entry is missing a valid issued timestamp"
  end

  if issued_epoch > now_value then
    return false, "authorization entry timestamp is in the future"
  end

  local age = now_value - issued_epoch
  if age > max_age then
    return false, "authorization entry is stale"
  end
  return true, nil
end

return placement_authorization_bridge
