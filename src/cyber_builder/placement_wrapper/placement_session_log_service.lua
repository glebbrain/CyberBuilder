local placement_session_log_service = {}

local PREFIX = "[PlacementWrapper]"
local core_logger = nil

function placement_session_log_service.set_core_logger(logger)
  core_logger = type(logger) == "table" and logger or nil
end

local function now_iso8601_utc()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function trim(s)
  if type(s) ~= "string" then
    return ""
  end
  return (s:match("^%s*(.-)%s*$") or "")
end

local function emit_to_core(level, message, ctx)
  if not core_logger then
    return
  end
  local lvl = trim(tostring(level or "INFO")):upper()
  if lvl == "ERROR" and type(core_logger.error) == "function" then
    core_logger.error(message, ctx)
  elseif lvl == "WARN" and type(core_logger.warn) == "function" then
    core_logger.warn(message, ctx)
  elseif type(core_logger.info) == "function" then
    core_logger.info(message, ctx)
  end
end

local function context_to_inline(ctx)
  if type(ctx) ~= "table" then
    return ""
  end
  local keys = {}
  for k, _ in pairs(ctx) do
    keys[#keys + 1] = tostring(k)
  end
  table.sort(keys)
  if #keys == 0 then
    return ""
  end
  local parts = {}
  for _, key in ipairs(keys) do
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

function placement_session_log_service.format(level, message, ctx)
  local lvl = trim(tostring(level or "INFO")):upper()
  if lvl == "" then
    lvl = "INFO"
  end
  local msg = trim(tostring(message or ""))
  local ts = now_iso8601_utc()
  return string.format("%s %s %s %s%s", PREFIX, ts, lvl, msg, context_to_inline(ctx))
end

function placement_session_log_service.log(level, message, ctx)
  local line = placement_session_log_service.format(level, message, ctx)
  print(line)
  local ctx_ext = { module = "placement_wrapper" }
  if type(ctx) == "table" then
    for k, v in pairs(ctx) do
      ctx_ext[k] = v
    end
  end
  emit_to_core(level, message, ctx_ext)
  return line
end

function placement_session_log_service.info(message, ctx)
  return placement_session_log_service.log("INFO", message, ctx)
end

function placement_session_log_service.warn(message, ctx)
  return placement_session_log_service.log("WARN", message, ctx)
end

function placement_session_log_service.error(message, ctx)
  return placement_session_log_service.log("ERROR", message, ctx)
end

return placement_session_log_service
