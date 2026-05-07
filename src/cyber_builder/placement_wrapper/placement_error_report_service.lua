local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local sep = package.config:sub(1, 1)
local path_utils = dofile(this_dir() .. ".." .. sep .. "path_utils.lua")
local placement_session_log_service = dofile(this_dir() .. "placement_session_log_service.lua")

local placement_error_report_service = {}

local function is_non_empty_string(v)
  return type(v) == "string" and v:find("%S") ~= nil
end

local function ensure_parent_dir(file_path)
  local parent = file_path:match("^(.*)[/\\][^/\\]+$")
  if not parent or parent == "" then
    return
  end
  if package.config:sub(1, 1) == "\\" then
    os.execute('cmd /c mkdir "' .. parent:gsub("/", "\\"):gsub('"', "") .. '" 2>nul')
  end
end

function placement_error_report_service.append(dist_dir, message, ctx)
  if not is_non_empty_string(dist_dir) then
    return false, "dist_dir must be a non-empty string"
  end
  local line = placement_session_log_service.format("ERROR", message or "", ctx)
  local log_path = path_utils.join(dist_dir, "placement_errors.log")
  ensure_parent_dir(log_path)
  local f, err = io.open(log_path, "ab")
  if not f then
    return false, string.format("cannot open %q for append (%s)", log_path, tostring(err or "unknown"))
  end
  f:write(line)
  f:write("\n")
  f:close()
  return true, nil
end

return placement_error_report_service
