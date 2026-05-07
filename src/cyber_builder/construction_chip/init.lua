local ConstructionChip = {}

local LOG_PREFIX = "[ConstructionChip]"
local core_logger = nil

function ConstructionChip.set_logger(logger)
  core_logger = type(logger) == "table" and logger or nil
end

local function make_line(level, message)
  local lvl = type(level) == "string" and level or "INFO"
  local msg = type(message) == "string" and message or tostring(message)
  return string.format("%s %s %s", LOG_PREFIX, lvl, msg)
end

function ConstructionChip.log(level, message)
  local line = make_line(level, message)
  print(line)
  if core_logger then
    local L = (type(level) == "string" and level or "INFO"):upper()
    local ctx = { module = "construction_chip" }
    if L == "ERROR" and type(core_logger.error) == "function" then
      core_logger.error(message, ctx)
    elseif L == "WARN" and type(core_logger.warn) == "function" then
      core_logger.warn(message, ctx)
    elseif type(core_logger.info) == "function" then
      core_logger.info(message, ctx)
    end
  end
  return line
end

function ConstructionChip.log_info(message)
  return ConstructionChip.log("INFO", message)
end

function ConstructionChip.log_warn(message)
  return ConstructionChip.log("WARN", message)
end

function ConstructionChip.log_error(message)
  return ConstructionChip.log("ERROR", message)
end

return ConstructionChip
