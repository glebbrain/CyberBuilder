local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local placement_ownership_service = dofile(this_dir() .. "placement_ownership_service.lua")

local placement_removal_service = {}

local function is_non_empty_string(v)
  return type(v) == "string" and v:find("%S") ~= nil
end

local function now_iso()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function build_safe_removal_metadata(placement_id, owner_id, removed_at)
  return {
    placementId = placement_id,
    ownerId = owner_id,
    state = "removed",
    removedAt = removed_at,
    removalMode = "metadata_only",
    touchedOriginalWorldObject = false,
  }
end

function placement_removal_service.validate_ownership_for_removal(placement_id, owner_id)
  if not is_non_empty_string(placement_id) then
    return false, "placement_id must be a non-empty string"
  end
  if not is_non_empty_string(owner_id) then
    return false, "owner_id must be a non-empty string"
  end
  if not placement_ownership_service.is_owner(placement_id, owner_id) then
    return false, "removal denied: placement is not owned by owner_id"
  end
  return true, nil
end

function placement_removal_service.create_request(placement_id, owner_id, session_id, provider)
  if not is_non_empty_string(placement_id) then
    return nil, "placement_id must be a non-empty string"
  end
  if not is_non_empty_string(owner_id) then
    return nil, "owner_id must be a non-empty string"
  end
  if not is_non_empty_string(provider) then
    return nil, "provider must be a non-empty string"
  end

  local owned, ownership_err = placement_removal_service.validate_ownership_for_removal(placement_id, owner_id)
  if not owned then
    return nil, ownership_err
  end

  local request = {
    requestId = string.format("remove:%s:%s", owner_id, placement_id),
    placementId = placement_id,
    ownerId = owner_id,
    sessionId = session_id,
    provider = provider,
    state = "pending",
    requestedAt = now_iso(),
  }
  return request, nil
end

function placement_removal_service.mark_removed(placement_id, owner_id)
  local removed_record, err = placement_ownership_service.remove(placement_id, owner_id)
  if removed_record == nil then
    return nil, err
  end
  return build_safe_removal_metadata(placement_id, owner_id, now_iso()), nil
end

return placement_removal_service
