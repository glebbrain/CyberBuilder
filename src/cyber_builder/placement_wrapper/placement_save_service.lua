local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local path_utils = dofile(this_dir() .. ".." .. package.config:sub(1, 1) .. "path_utils.lua")

local placement_save_service = {}

local function json_escape(s)
  return s:gsub('[%z\1-\31\\"]', function(c)
    local map = {
      ['"'] = '\\"',
      ["\\"] = "\\\\",
      ["\b"] = "\\b",
      ["\f"] = "\\f",
      ["\n"] = "\\n",
      ["\r"] = "\\r",
      ["\t"] = "\\t",
    }
    return map[c] or string.format("\\u%04x", c:byte())
  end)
end

local function json_encode(v)
  local t = type(v)
  if t == "nil" then
    return "null"
  end
  if t == "boolean" then
    return v and "true" or "false"
  end
  if t == "number" then
    return string.format("%.14g", v)
  end
  if t == "string" then
    return '"' .. json_escape(v) .. '"'
  end
  if t ~= "table" then
    error("unsupported json type: " .. t)
  end

  if #v > 0 then
    local arr = {}
    for i = 1, #v do
      arr[#arr + 1] = json_encode(v[i])
    end
    return "[" .. table.concat(arr, ",") .. "]"
  end

  local keys = {}
  for k in pairs(v) do
    if type(k) == "string" then
      keys[#keys + 1] = k
    end
  end
  table.sort(keys)
  local obj = {}
  for _, k in ipairs(keys) do
    obj[#obj + 1] = json_encode(k) .. ":" .. json_encode(v[k])
  end
  return "{" .. table.concat(obj, ",") .. "}"
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

function placement_save_service.write_json(file_path, payload)
  if type(file_path) ~= "string" or file_path == "" then
    return false, "file_path must be a non-empty string"
  end
  if type(payload) ~= "table" then
    return false, "payload must be a table"
  end

  local ok, body = pcall(json_encode, payload)
  if not ok then
    return false, "cannot encode payload as JSON"
  end

  ensure_parent_dir(file_path)
  local f, err = io.open(file_path, "wb")
  if not f then
    return false, string.format("cannot open %q for write (%s)", file_path, tostring(err or "unknown"))
  end
  f:write(body)
  f:write("\n")
  f:close()
  return true, nil
end

function placement_save_service.save_player_placements(dist_dir, placements)
  if type(dist_dir) ~= "string" or dist_dir == "" then
    return false, "dist_dir must be a non-empty string"
  end
  if type(placements) ~= "table" then
    return false, "placements must be a table"
  end
  local out_path = path_utils.join(dist_dir, "player_placements.json")
  return placement_save_service.write_json(out_path, placements)
end

return placement_save_service
