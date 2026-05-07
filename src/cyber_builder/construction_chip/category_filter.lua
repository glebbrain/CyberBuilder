local category_filter = {}

category_filter.ALLOWLIST_CATEGORIES = {
  Furniture = true,
  Decor = true,
  Light = true,
  StaticMesh = true,
  Interior = true,
  Workbench = true,
  Container = true,
}

category_filter.DENYLIST_CATEGORIES = {
  NPC = true,
  Vehicle = true,
  Quest = true,
  Door = true,
  Elevator = true,
  Combat = true,
  Device = true,
  Scripted = true,
  PhysicsCritical = true,
}

local function trim(s)
  if type(s) ~= "string" then
    return ""
  end
  return (s:match("^%s*(.-)%s*$") or "")
end

function category_filter.normalize_category(category)
  local value = trim(category)
  if value == "" then
    return ""
  end
  return value:gsub("[%s_%-]+", ""):lower()
end

function category_filter.is_allowed(category, allowlist)
  local normalized = category_filter.normalize_category(category)
  if normalized == "" then
    return false
  end
  if type(allowlist) ~= "table" then
    return false
  end
  for allow_category, enabled in pairs(allowlist) do
    if enabled == true and category_filter.normalize_category(allow_category) == normalized then
      return true
    end
  end
  return false
end

function category_filter.is_denied(category, denylist)
  local normalized = category_filter.normalize_category(category)
  if normalized == "" then
    return false
  end
  if type(denylist) ~= "table" then
    return false
  end
  for deny_category, enabled in pairs(denylist) do
    if enabled == true and category_filter.normalize_category(deny_category) == normalized then
      return true
    end
  end
  return false
end

function category_filter.filter_objects(objects, allowlist, denylist)
  if type(objects) ~= "table" then
    return nil, "objects must be an array table"
  end

  local allowed = {}
  local blocked = {}

  for _, obj in ipairs(objects) do
    if type(obj) == "table" then
      local category = category_filter.normalize_category(obj.category)
      local is_denied = category_filter.is_denied(category, denylist)
      local is_allowed = category_filter.is_allowed(category, allowlist)

      if category ~= "" and not is_denied and is_allowed then
        allowed[#allowed + 1] = obj
      else
        blocked[#blocked + 1] = obj
      end
    end
  end

  return {
    allowed = allowed,
    blocked = blocked,
  }, nil
end

function category_filter.validate_unsafe_categories_filtered(filtered_result, denylist)
  if type(filtered_result) ~= "table" then
    return nil, "filtered_result must be a table"
  end
  if type(denylist) ~= "table" then
    return nil, "denylist must be a table"
  end

  local allowed = type(filtered_result.allowed) == "table" and filtered_result.allowed or {}
  for i, obj in ipairs(allowed) do
    if type(obj) == "table" then
      local category = trim(obj.category)
      if category_filter.is_denied(category, denylist) then
        return false, string.format(
          "unsafe category %q appears in allowed results at index %d",
          category,
          i
        )
      end
    end
  end

  return true, nil
end

function category_filter.collect_normalization_warnings(objects, allowlist, denylist)
  if type(objects) ~= "table" then
    return nil, "objects must be an array table"
  end

  local warnings = {}
  for i, obj in ipairs(objects) do
    if type(obj) == "table" then
      local raw = trim(obj.category)
      local normalized = category_filter.normalize_category(raw)
      if raw ~= "" and normalized ~= "" then
        local is_allowed = category_filter.is_allowed(normalized, allowlist or {})
        local is_denied = category_filter.is_denied(normalized, denylist or {})
        if not is_allowed and not is_denied then
          warnings[#warnings + 1] = string.format(
            "category normalization warning at index %d: raw=%q normalized=%q does not match allow/deny rules",
            i,
            raw,
            normalized
          )
        end
      end
    end
  end

  return warnings, nil
end

return category_filter
