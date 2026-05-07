local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local placement_ownership_service = dofile(this_dir() .. "placement_ownership_service.lua")
local placement_save_service = dofile(this_dir() .. "placement_save_service.lua")

local placement_ownership_registry_service = {}

local function project_ownership_fields(entry)
  return {
    placementId = entry.placementId,
    ownerId = entry.ownerId,
    packId = entry.packId,
    objectId = entry.objectId,
    provider = entry.provider,
    createdAt = entry.createdAt,
    lastModifiedAt = entry.lastModifiedAt,
  }
end

function placement_ownership_registry_service.save_registry(dist_dir)
  local source = placement_ownership_service.list_all()
  local placements = {}
  for i, entry in ipairs(source) do
    placements[i] = project_ownership_fields(entry)
  end
  return placement_save_service.save_player_placements(dist_dir, placements)
end

return placement_ownership_registry_service
