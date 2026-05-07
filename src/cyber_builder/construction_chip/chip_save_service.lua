local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local path_utils = dofile(this_dir() .. ".." .. package.config:sub(1, 1) .. "path_utils.lua")

local chip_save_service = {}

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

function chip_save_service.write_json(file_path, payload)
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

function chip_save_service.save_unlock_state(save_dir, unlock_state)
  if type(save_dir) ~= "string" or save_dir == "" then
    return false, "save_dir must be a non-empty string"
  end
  if type(unlock_state) ~= "table" then
    return false, "unlock_state must be a table"
  end

  local out_path = path_utils.join(save_dir, "player_unlocks.json")
  return chip_save_service.write_json(out_path, unlock_state)
end

return chip_save_service
