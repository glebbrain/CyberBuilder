-- Single instance across all `dofile(...)` callers (e.g. tests load this file directly while
-- `placement_removal_service.lua` also loads it; without caching, ownership tables diverge).
local MODULE_KEY = "cyber_builder.placement_wrapper.placement_ownership_service"
if package.loaded[MODULE_KEY] then
  return package.loaded[MODULE_KEY]
end

local placement_ownership_service = {}

local ownership_by_placement_id = {}

local function is_non_empty_string(v)
  return type(v) == "string" and v:find("%S") ~= nil
end

local function now_iso()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function shallow_copy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = v
  end
  return out
end

function placement_ownership_service.register(entry)
  if type(entry) ~= "table" then
    return nil, "ownership entry must be an object"
  end
  if not is_non_empty_string(entry.placementId) then
    return nil, "placementId must be a non-empty string"
  end
  if not is_non_empty_string(entry.ownerId) then
    return nil, "ownerId must be a non-empty string"
  end
  if not is_non_empty_string(entry.packId) then
    return nil, "packId must be a non-empty string"
  end
  if not is_non_empty_string(entry.objectId) then
    return nil, "objectId must be a non-empty string"
  end
  if not is_non_empty_string(entry.provider) then
    return nil, "provider must be a non-empty string"
  end
  if ownership_by_placement_id[entry.placementId] ~= nil then
    return nil, "placement ownership already exists"
  end

  local timestamp = now_iso()
  local record = {
    placementId = entry.placementId,
    ownerId = entry.ownerId,
    packId = entry.packId,
    objectId = entry.objectId,
    provider = entry.provider,
    createdAt = entry.createdAt or timestamp,
    lastModifiedAt = entry.lastModifiedAt or timestamp,
  }
  ownership_by_placement_id[record.placementId] = record
  return shallow_copy(record), nil
end

function placement_ownership_service.get(placement_id)
  local record = ownership_by_placement_id[placement_id]
  if record == nil then
    return nil
  end
  return shallow_copy(record)
end

function placement_ownership_service.detect_duplicate_placement_id(placement_id)
  if not is_non_empty_string(placement_id) then
    return false, "placement_id must be a non-empty string"
  end
  if ownership_by_placement_id[placement_id] ~= nil then
    return true, "duplicate placement id detected"
  end
  return false, nil
end

function placement_ownership_service.is_owner(placement_id, owner_id)
  local record = ownership_by_placement_id[placement_id]
  return record ~= nil and record.ownerId == owner_id
end

function placement_ownership_service.remove(placement_id, owner_id)
  local record = ownership_by_placement_id[placement_id]
  if record == nil then
    return nil, "placement ownership not found"
  end
  if record.ownerId ~= owner_id then
    return nil, "owner mismatch"
  end
  ownership_by_placement_id[placement_id] = nil
  return shallow_copy(record), nil
end

function placement_ownership_service.list_by_owner(owner_id)
  local out = {}
  for _, record in pairs(ownership_by_placement_id) do
    if record.ownerId == owner_id then
      out[#out + 1] = shallow_copy(record)
    end
  end
  table.sort(out, function(a, b)
    return a.placementId < b.placementId
  end)
  return out
end

function placement_ownership_service.list_all()
  local out = {}
  for _, record in pairs(ownership_by_placement_id) do
    out[#out + 1] = shallow_copy(record)
  end
  table.sort(out, function(a, b)
    return a.placementId < b.placementId
  end)
  return out
end

function placement_ownership_service.reset()
  ownership_by_placement_id = {}
end

package.loaded[MODULE_KEY] = placement_ownership_service
return placement_ownership_service
