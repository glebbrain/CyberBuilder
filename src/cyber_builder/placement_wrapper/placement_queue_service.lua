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

local placement_queue_service = {}

local function is_non_empty_string(v)
  return type(v) == "string" and v:find("%S") ~= nil
end

function placement_queue_service.enqueue_export_payload(dist_dir, export_payload)
  if not is_non_empty_string(dist_dir) then
    return false, "dist_dir must be a non-empty string"
  end
  if type(export_payload) ~= "table" then
    return false, "export_payload must be a table"
  end
  if not is_non_empty_string(export_payload.requestId) then
    return false, "export_payload.requestId must be a non-empty string"
  end

  local queue_dir = path_utils.join(dist_dir, "placement_queue")
  local file_name = export_payload.requestId .. ".json"
  local file_path = path_utils.join(queue_dir, file_name)
  return placement_save_service.write_json(file_path, export_payload)
end

function placement_queue_service.enqueue_export_payloads_deterministic(dist_dir, export_payloads)
  if not is_non_empty_string(dist_dir) then
    return false, "dist_dir must be a non-empty string"
  end
  if type(export_payloads) ~= "table" then
    return false, "export_payloads must be a table"
  end

  local queue = {}
  for i, payload in ipairs(export_payloads) do
    if type(payload) ~= "table" then
      return false, string.format("export_payloads[%d] must be a table", i)
    end
    if not is_non_empty_string(payload.requestId) then
      return false, string.format("export_payloads[%d].requestId must be a non-empty string", i)
    end
    queue[#queue + 1] = payload
  end

  table.sort(queue, function(a, b)
    return a.requestId < b.requestId
  end)

  for _, payload in ipairs(queue) do
    local ok, err = placement_queue_service.enqueue_export_payload(dist_dir, payload)
    if not ok then
      return false, err
    end
  end
  return true, nil
end

return placement_queue_service
