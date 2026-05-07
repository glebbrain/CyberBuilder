local unlock_registry = {}

local state = {
  entries = {},
  unlocked = {},
}

local function trim(s)
  if type(s) ~= "string" then
    return ""
  end
  return (s:match("^%s*(.-)%s*$") or "")
end

local function sorted_keys(tbl)
  local keys = {}
  for k in pairs(tbl) do
    keys[#keys + 1] = k
  end
  table.sort(keys)
  return keys
end

function unlock_registry.register(unlock_id, data)
  local id = trim(unlock_id)
  if id == "" then
    return false, "unlock_id must be a non-empty string"
  end
  if state.entries[id] ~= nil then
    return false, string.format("unlock id %q already registered", id)
  end
  state.entries[id] = type(data) == "table" and data or {}
  return true, nil
end

function unlock_registry.is_registered(unlock_id)
  local id = trim(unlock_id)
  if id == "" then
    return false
  end
  return state.entries[id] ~= nil
end

function unlock_registry.unlock(unlock_id)
  local id = trim(unlock_id)
  if id == "" then
    return false, "unlock_id must be a non-empty string"
  end
  if state.entries[id] == nil then
    return false, string.format("unlock id %q is not registered", id)
  end
  state.unlocked[id] = true
  return true, nil
end

function unlock_registry.is_unlocked(unlock_id)
  local id = trim(unlock_id)
  if id == "" then
    return false
  end
  return state.unlocked[id] == true
end

function unlock_registry.list_registered()
  return sorted_keys(state.entries)
end

function unlock_registry.list_unlocked()
  return sorted_keys(state.unlocked)
end

function unlock_registry.validate_no_duplicate_unlock_ids(unlock_ids)
  if type(unlock_ids) ~= "table" then
    return nil, "unlock_ids must be an array table"
  end

  local seen = {}
  for i, raw_id in ipairs(unlock_ids) do
    local id = trim(raw_id)
    if id == "" then
      return false, string.format("unlock id at index %d must be a non-empty string", i)
    end
    if seen[id] then
      return false, string.format(
        "duplicate unlock id %q (first at index %d, duplicate at index %d)",
        id,
        seen[id],
        i
      )
    end
    seen[id] = i
  end

  return true, nil
end

function unlock_registry.validate_known_object_ids(unlock_object_ids, known_object_ids)
  if type(unlock_object_ids) ~= "table" then
    return nil, "unlock_object_ids must be an array table"
  end
  if type(known_object_ids) ~= "table" then
    return nil, "known_object_ids must be a table"
  end

  local known = {}
  for _, raw_id in ipairs(known_object_ids) do
    local id = trim(raw_id)
    if id ~= "" then
      known[id] = true
    end
  end

  for i, raw_unlock_id in ipairs(unlock_object_ids) do
    local unlock_id = trim(raw_unlock_id)
    if unlock_id == "" then
      return false, string.format("unlock object id at index %d must be a non-empty string", i)
    end
    if not known[unlock_id] then
      return false, string.format("unlock object id %q is not a known object id", unlock_id)
    end
  end

  return true, nil
end

function unlock_registry.reset()
  state.entries = {}
  state.unlocked = {}
end

return unlock_registry
