local ConstructionChip = {}

local LOG_PREFIX = "[ConstructionChip]"

local function make_line(level, message)
  local lvl = type(level) == "string" and level or "INFO"
  local msg = type(message) == "string" and message or tostring(message)
  return string.format("%s %s %s", LOG_PREFIX, lvl, msg)
end

function ConstructionChip.log(level, message)
  local line = make_line(level, message)
  print(line)
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
