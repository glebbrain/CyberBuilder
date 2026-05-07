local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local sep = package.config:sub(1, 1)
local json_loader = dofile(this_dir() .. ".." .. sep .. "json_loader.lua")
local path_utils = dofile(this_dir() .. ".." .. sep .. "path_utils.lua")

local chip_load_service = {}

local function starter_unlock_fallback_table()
  return {
    version = "0.3.0",
    chipState = "installed",
    activeTier = "Tier1",
    unlockedTiers = { "Tier1" },
    unlockedObjectIds = {},
    updatedAt = "1970-01-01T00:00:00Z",
  }
end

function chip_load_service.read_json(file_path)
  if type(file_path) ~= "string" or file_path == "" then
    return nil, "file_path must be a non-empty string"
  end
  return json_loader.read(file_path)
end

function chip_load_service.load_unlock_state(save_dir)
  if type(save_dir) ~= "string" or save_dir == "" then
    return nil, "save_dir must be a non-empty string"
  end
  local in_path = path_utils.join(save_dir, "player_unlocks.json")
  return chip_load_service.read_json(in_path)
end

function chip_load_service.load_unlock_state_with_fallback(save_dir)
  local data, err = chip_load_service.load_unlock_state(save_dir)
  if data then
    return data, nil
  end

  return starter_unlock_fallback_table(),
    string.format("unlock save load failed, used fallback: %s", tostring(err or "unknown"))
end

return chip_load_service
