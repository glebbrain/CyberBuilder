-- Pack registry: discover immediate child pack folders under a packs root.
local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local path_utils = dofile(this_dir() .. "path_utils.lua")

local pack_registry = {}

local function is_windows_sep()
  return package.config:sub(1, 1) == "\\"
end

local function list_with_lfs(packs_dir, lfs)
  local mode = lfs.attributes(packs_dir, "mode")
  if mode ~= "directory" then
    return nil, string.format("pack_registry.discover: not a directory %q", packs_dir)
  end
  local out = {}
  for name in lfs.dir(packs_dir) do
    if name ~= "." and name ~= ".." then
      local child = path_utils.join(packs_dir, name)
      if lfs.attributes(child, "mode") == "directory" then
        out[#out + 1] = { id = name, path = child }
      end
    end
  end
  table.sort(out, function(a, b)
    return a.id < b.id
  end)
  return out, nil
end

local function list_with_dir_cmd(packs_dir)
  if packs_dir:find('"', 1, true) then
    return nil, "pack_registry.discover: packs_dir must not contain a double quote character"
  end
  local cmd = string.format('cmd /c "dir /ad /b "%s""', packs_dir)
  local pipe = io.popen(cmd, "r")
  if not pipe then
    return nil, "pack_registry.discover: could not run directory listing (io.popen failed)"
  end
  local names = {}
  for line in pipe:lines() do
    if line ~= "" and line ~= "." and line ~= ".." then
      names[#names + 1] = line
    end
  end
  pipe:close()
  local out = {}
  for _, name in ipairs(names) do
    local child = path_utils.join(packs_dir, name)
    out[#out + 1] = { id = name, path = child }
  end
  table.sort(out, function(a, b)
    return a.id < b.id
  end)
  return out, nil
end

--- Return sorted array of `{ id = folderName, path = fullChildPath }` for each direct subdirectory of `packs_dir`.
-- On success: `packs, nil`. On failure: `nil, err`.
function pack_registry.discover(packs_dir)
  if type(packs_dir) ~= "string" or packs_dir == "" then
    return nil, "pack_registry.discover: packs_dir must be a non-empty string"
  end
  packs_dir = packs_dir:gsub("[/\\]+$", "")
  local ok_lfs, lfs = pcall(require, "lfs")
  if ok_lfs then
    return list_with_lfs(packs_dir, lfs)
  end
  if is_windows_sep() then
    return list_with_dir_cmd(packs_dir)
  end
  return nil, "pack_registry.discover: install LuaFileSystem (luarocks install luafilesystem) for directory listing on this platform"
end

return pack_registry
