local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local sep = package.config:sub(1, 1)
local path_utils = dofile(this_dir() .. ".." .. sep .. "path_utils.lua")
local json_loader = dofile(this_dir() .. ".." .. sep .. "json_loader.lua")
local placement_save_service = dofile(this_dir() .. "placement_save_service.lua")

local placement_load_service = {}

function placement_load_service.read_json(file_path)
  if type(file_path) ~= "string" or file_path == "" then
    return nil, "file_path must be a non-empty string"
  end
  return json_loader.read(file_path)
end

function placement_load_service.load_player_placements(dist_dir)
  if type(dist_dir) ~= "string" or dist_dir == "" then
    return nil, "dist_dir must be a non-empty string"
  end
  local in_path = path_utils.join(dist_dir, "player_placements.json")
  local decoded, err = placement_load_service.read_json(in_path)
  if decoded == nil then
    return nil, err
  end
  if type(decoded) ~= "table" then
    return nil, "player_placements.json must decode to a table"
  end
  return decoded, nil
end

function placement_load_service.load_player_placements_with_recovery(dist_dir)
  local decoded, err = placement_load_service.load_player_placements(dist_dir)
  if decoded ~= nil then
    return decoded, nil, false
  end

  local recovered = {}
  local saved, save_err = placement_save_service.save_player_placements(dist_dir, recovered)
  if not saved then
    return nil, string.format("corrupted save recovery failed (%s)", tostring(save_err or "unknown"))
  end
  return recovered, nil, true
end

return placement_load_service
