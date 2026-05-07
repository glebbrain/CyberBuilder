-- Central logger: levels, sinks, and contextual records.
local PREFIX = "[CyberBuilder]"

local logger = {}

local LEVEL_VALUE = {
  DEBUG = 10,
  INFO = 20,
  WARN = 30,
  ERROR = 40,
}

local VALID_TARGET = {
  console = true,
  files = true,
  external = true,
}

local state = {
  min_level = LEVEL_VALUE.INFO,
  targets = { console = true },
  context = {},
  main_file_path = nil,
  error_file_path = nil,
  external_handler = nil,
  mirror_warn_to_error_file = false,
}

local function now_iso8601_utc()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function trim(s)
  if type(s) ~= "string" then
    return ""
  end
  return (s:match("^%s*(.-)%s*$") or "")
end

local function normalize_level(raw)
  local level = trim(tostring(raw or "")):upper()
  if not LEVEL_VALUE[level] then
    return "INFO"
  end
  return level
end

local function shallow_copy(tbl)
  local out = {}
  if type(tbl) ~= "table" then
    return out
  end
  for k, v in pairs(tbl) do
    out[k] = v
  end
  return out
end

local function merge_context(local_ctx)
  local merged = shallow_copy(state.context)
  if type(local_ctx) == "table" then
    for k, v in pairs(local_ctx) do
      merged[k] = v
    end
  end
  return merged
end

local function context_to_inline(ctx)
  local keys = {}
  for k, _ in pairs(ctx or {}) do
    keys[#keys + 1] = tostring(k)
  end
  table.sort(keys)
  if #keys == 0 then
    return ""
  end
  local parts = {}
  for i = 1, #keys do
    local key = keys[i]
    local val = ctx[key]
    if val ~= nil then
      parts[#parts + 1] = key .. "=" .. tostring(val)
    end
  end
  if #parts == 0 then
    return ""
  end
  return " [" .. table.concat(parts, " ") .. "]"
end

local function ensure_parent_dir_for(file_path)
  local parent = file_path:match("^(.*)[/\\][^/\\]+$")
  if not parent or parent == "" then
    return true
  end
  if package.config:sub(1, 1) == "\\" then
    os.execute('cmd /c mkdir "' .. parent:gsub("/", "\\"):gsub('"', "") .. '" 2>nul')
    return true
  end
  local lfs_ok, lfs = pcall(require, "lfs")
  if not lfs_ok or not lfs or not lfs.mkdir then
    return false
  end
  local acc = nil
  for piece in parent:gmatch("[^/\\]+") do
    acc = acc and (acc .. "/" .. piece) or piece
    pcall(lfs.mkdir, acc)
  end
  return true
end

local function append_line(path, line)
  if type(path) ~= "string" or path == "" then
    return false, "path is empty"
  end
  ensure_parent_dir_for(path)
  local f, err = io.open(path, "ab")
  if not f then
    return false, err or "unknown open error"
  end
  f:write(line)
  f:write("\n")
  f:close()
  return true, nil
end

local function emit_external(record)
  if not state.targets.external then
    return
  end
  if type(state.external_handler) ~= "function" then
    return
  end
  pcall(state.external_handler, record)
end

local function should_emit(level)
  return LEVEL_VALUE[level] >= state.min_level
end

local function emit(level, msg, local_ctx)
  local lvl = normalize_level(level)
  if not should_emit(lvl) then
    return
  end
  local message = tostring(msg)
  local merged_ctx = merge_context(local_ctx)
  local ts = now_iso8601_utc()
  local ctx_inline = context_to_inline(merged_ctx)
  local line = string.format("%s %s %s%s", PREFIX, lvl, message, ctx_inline)
  local file_line = string.format("%s %s %s%s", ts, lvl, message, ctx_inline)
  local record = {
    timestamp = ts,
    level = lvl,
    message = message,
    context = merged_ctx,
    line = line,
  }
  if state.targets.console then
    print(line)
  end
  if state.targets.files and state.main_file_path then
    append_line(state.main_file_path, file_line)
    if state.error_file_path and (lvl == "ERROR" or (lvl == "WARN" and state.mirror_warn_to_error_file)) then
      append_line(state.error_file_path, file_line)
    end
  end
  emit_external(record)
end

function logger.configure(opts)
  opts = type(opts) == "table" and opts or {}
  local level = normalize_level(opts.level or opts.min_level or "INFO")
  state.min_level = LEVEL_VALUE[level]

  local TARGET_ALIASES = {
    file = "files",
  }
  local targets = {}
  if type(opts.targets) == "table" then
    for _, t in ipairs(opts.targets) do
      local key = trim(tostring(t)):lower()
      key = TARGET_ALIASES[key] or key
      if VALID_TARGET[key] then
        targets[key] = true
      end
    end
  end
  if next(targets) == nil then
    targets.console = true
  end
  state.targets = targets

  if type(opts.context) == "table" then
    state.context = shallow_copy(opts.context)
  else
    state.context = {}
  end
  state.main_file_path = type(opts.mainFilePath) == "string" and trim(opts.mainFilePath) ~= "" and opts.mainFilePath or nil
  state.error_file_path = type(opts.errorFilePath) == "string" and trim(opts.errorFilePath) ~= "" and opts.errorFilePath or nil
  state.external_handler = type(opts.externalHandler) == "function" and opts.externalHandler or nil
  state.mirror_warn_to_error_file = opts.mirrorWarnToErrorFile == true
end

function logger.with_context(ctx)
  local child = {}
  local merged = merge_context(ctx)
  local function bind(level)
    return function(msg, local_ctx)
      local ext = shallow_copy(merged)
      if type(local_ctx) == "table" then
        for k, v in pairs(local_ctx) do
          ext[k] = v
        end
      end
      emit(level, msg, ext)
    end
  end
  child.debug = bind("DEBUG")
  child.info = bind("INFO")
  child.warn = bind("WARN")
  child.error = bind("ERROR")
  return child
end

function logger.debug(msg, ctx)
  emit("DEBUG", msg, ctx)
end

function logger.info(msg, ctx)
  emit("INFO", msg, ctx)
end

function logger.warn(msg, ctx)
  emit("WARN", msg, ctx)
end

function logger.error(msg, ctx)
  emit("ERROR", msg, ctx)
end

function logger.make_error_line(msg, code, ctx)
  local merged = merge_context(ctx)
  if type(code) == "string" and code ~= "" then
    merged.code = code
  end
  local ctx_inline = context_to_inline(merged)
  return string.format("%s ERROR %s%s", PREFIX, tostring(msg), ctx_inline)
end

function logger.get_level()
  for name, v in pairs(LEVEL_VALUE) do
    if v == state.min_level then
      return name
    end
  end
  return "INFO"
end

return logger
