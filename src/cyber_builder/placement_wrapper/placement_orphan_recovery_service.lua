local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local placement_load_service = dofile(this_dir() .. "placement_load_service.lua")
local placement_ownership_service = dofile(this_dir() .. "placement_ownership_service.lua")

local placement_orphan_recovery_service = {}

local function validate_entry(entry)
  if type(entry) ~= "table" then
    return false, "entry must be an object"
  end
  if type(entry.placementId) ~= "string" or entry.placementId == "" then
    return false, "missing placementId"
  end
  if type(entry.ownerId) ~= "string" or entry.ownerId == "" then
    return false, "missing ownerId"
  end
  if type(entry.packId) ~= "string" or entry.packId == "" then
    return false, "missing packId"
  end
  if type(entry.objectId) ~= "string" or entry.objectId == "" then
    return false, "missing objectId"
  end
  if type(entry.provider) ~= "string" or entry.provider == "" then
    return false, "missing provider"
  end
  return true, nil
end

function placement_orphan_recovery_service.recover_from_saved_registry(dist_dir)
  local decoded, load_err = placement_load_service.load_player_placements(dist_dir)
  if decoded == nil then
    return nil, load_err
  end

  local recovered = {}
  local orphans = {}

  for idx, entry in ipairs(decoded) do
    local valid, reason = validate_entry(entry)
    if not valid then
      orphans[#orphans + 1] = { index = idx, reason = reason }
    else
      local _, register_err = placement_ownership_service.register(entry)
      if register_err ~= nil then
        orphans[#orphans + 1] = {
          index = idx,
          placementId = entry.placementId,
          reason = register_err,
        }
      else
        recovered[#recovered + 1] = entry.placementId
      end
    end
  end

  return {
    recoveredPlacementIds = recovered,
    orphanedEntries = orphans,
    recoveredCount = #recovered,
    orphanedCount = #orphans,
  }, nil
end

return placement_orphan_recovery_service
