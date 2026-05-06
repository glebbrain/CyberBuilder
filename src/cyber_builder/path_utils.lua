-- Path helpers: join (OS-aware), slash normalization, extension, safe relative checks.
local path_utils = {}

local function dir_sep()
  return package.config:sub(1, 1)
end

--- Join path segments using the host directory separator. Empty parts are skipped.
function path_utils.join(...)
  local sep = dir_sep()
  local parts = {}
  for i = 1, select("#", ...) do
    local p = select(i, ...)
    if type(p) == "string" and p ~= "" then
      parts[#parts + 1] = p
    end
  end
  if #parts == 0 then
    return ""
  end
  local acc = parts[1]
  for i = 2, #parts do
    acc = acc:gsub("[/\\]+$", "") .. sep .. parts[i]:gsub("^[/\\]+", "")
  end
  return acc
end

--- Normalize to forward slashes, collapse repeats, trim trailing slash (except root "/").
function path_utils.normalize(path)
  if path == nil then
    return ""
  end
  local p = tostring(path):gsub("\\", "/")
  p = p:gsub("/+", "/")
  if p ~= "/" then
    p = p:gsub("/$", "")
  end
  return p
end

--- Return lowercased file extension including the dot (e.g. `.json`), or "" if none.
function path_utils.extension(path)
  if path == nil or path == "" then
    return ""
  end
  local base = tostring(path):gsub("\\", "/")
  local name = base:match("([^/]+)$") or base
  local ext = name:match("(%.[^./]+)$")
  if not ext then
    return ""
  end
  return ext:lower()
end

--- True if `path` is a relative path without `..` segments or obvious absolute prefixes.
function path_utils.is_safe_relative(path)
  if path == nil or path == "" then
    return false
  end
  local raw = tostring(path)
  if raw:find("%z") then
    return false
  end
  if raw:match("^%a:") or raw:match("^[/\\]") or raw:match("^\\\\") then
    return false
  end
  local n = path_utils.normalize(raw)
  if n == "" then
    return false
  end
  if n:sub(1, 1) == "/" then
    return false
  end
  if n:match("^%a:/") then
    return false
  end
  for segment in string.gmatch(n, "([^/]+)") do
    if segment == ".." then
      return false
    end
  end
  return true
end

return path_utils
