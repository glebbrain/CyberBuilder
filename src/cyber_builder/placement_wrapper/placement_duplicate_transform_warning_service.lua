local placement_duplicate_transform_warning_service = {}

local function normalize_number(n)
  if type(n) ~= "number" then
    return "?"
  end
  return string.format("%.6f", n)
end

local function transform_signature(transform)
  if type(transform) ~= "table" then
    return nil
  end
  local p = transform.position
  local r = transform.rotation
  local s = transform.scale
  if type(p) ~= "table" or type(r) ~= "table" or type(s) ~= "number" then
    return nil
  end
  return table.concat({
    normalize_number(p.x),
    normalize_number(p.y),
    normalize_number(p.z),
    normalize_number(r.pitch),
    normalize_number(r.yaw),
    normalize_number(r.roll),
    normalize_number(s),
  }, "|")
end

function placement_duplicate_transform_warning_service.detect_warnings(requests)
  if type(requests) ~= "table" then
    return nil, "requests must be a table"
  end

  local signatures = {}
  local warnings = {}

  for idx, request in ipairs(requests) do
    if type(request) == "table" then
      local signature = transform_signature(request.transform or request)
      if signature ~= nil then
        local existing = signatures[signature]
        if existing ~= nil then
          warnings[#warnings + 1] = {
            warning = "duplicate placement transform detected",
            firstIndex = existing.index,
            duplicateIndex = idx,
            firstRequestId = existing.requestId,
            duplicateRequestId = request.requestId,
          }
        else
          signatures[signature] = {
            index = idx,
            requestId = request.requestId,
          }
        end
      end
    end
  end

  return warnings, nil
end

return placement_duplicate_transform_warning_service
