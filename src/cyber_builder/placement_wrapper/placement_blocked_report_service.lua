local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local sep = package.config:sub(1, 1)
local path_utils = dofile(this_dir() .. ".." .. sep .. "path_utils.lua")
local placement_save_service = dofile(this_dir() .. "placement_save_service.lua")

local placement_blocked_report_service = {}

local function is_non_empty_string(v)
  return type(v) == "string" and v:find("%S") ~= nil
end

function placement_blocked_report_service.write_report(dist_dir, blocked_entries)
  if not is_non_empty_string(dist_dir) then
    return false, "dist_dir must be a non-empty string"
  end
  if type(blocked_entries) ~= "table" then
    return false, "blocked_entries must be a table"
  end
  local report_path = path_utils.join(dist_dir, "blocked_placements.json")
  return placement_save_service.write_json(report_path, blocked_entries)
end

return placement_blocked_report_service
