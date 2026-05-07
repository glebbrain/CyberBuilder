local placement_session_service = {}

local VALID_STATES = {
  pending = true,
  validated = true,
  delegated = true,
  placed = true,
  failed = true,
  removed = true,
}

local sessions = {}

local function is_non_empty_string(v)
  return type(v) == "string" and v:find("%S") ~= nil
end

local function shallow_copy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = v
  end
  return out
end

local function now_iso()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function now_epoch()
  return os.time(os.date("!*t"))
end

local function to_number(v)
  if type(v) == "number" then
    return v
  end
  local n = tonumber(v)
  return n
end

function placement_session_service.create(session_id, owner_id, provider, expires_at)
  if not is_non_empty_string(session_id) then
    return nil, "session id must be a non-empty string"
  end
  if not is_non_empty_string(owner_id) then
    return nil, "owner id must be a non-empty string"
  end
  if not is_non_empty_string(provider) then
    return nil, "provider must be a non-empty string"
  end
  if sessions[session_id] ~= nil then
    return nil, "session already exists"
  end

  local created_at = now_iso()
  local created_epoch = now_epoch()
  local session = {
    sessionId = session_id,
    ownerId = owner_id,
    provider = provider,
    state = "pending",
    createdAt = created_at,
    createdAtEpoch = created_epoch,
    lastModifiedAt = created_at,
    lastModifiedAtEpoch = created_epoch,
    expiresAt = expires_at,
  }
  sessions[session_id] = session
  return shallow_copy(session), nil
end

function placement_session_service.get(session_id)
  local session = sessions[session_id]
  if session == nil then
    return nil
  end
  return shallow_copy(session)
end

function placement_session_service.set_state(session_id, next_state)
  local session = sessions[session_id]
  if session == nil then
    return nil, "session not found"
  end
  if not VALID_STATES[next_state] then
    return nil, "invalid session state"
  end
  session.state = next_state
  session.lastModifiedAt = now_iso()
  session.lastModifiedAtEpoch = now_epoch()
  return shallow_copy(session), nil
end

function placement_session_service.remove_expired(now_epoch_seconds)
  local now_value = to_number(now_epoch_seconds)
  if now_value == nil then
    return nil, "now must be a number"
  end

  local removed = {}
  for session_id, session in pairs(sessions) do
    local expires = to_number(session.expiresAt)
    if expires ~= nil and expires <= now_value then
      sessions[session_id] = nil
      removed[#removed + 1] = session_id
    end
  end
  table.sort(removed)
  return removed, nil
end

-- Cleanup sessions that exceeded timeout window since last modification.
-- Returns `{ removedSessionId, ... }, nil` or `nil, "error"`.
function placement_session_service.cleanup_timed_out(now_epoch_seconds, timeout_seconds)
  local now_value = to_number(now_epoch_seconds)
  if now_value == nil then
    return nil, "now_epoch_seconds must be a number"
  end
  local timeout_value = to_number(timeout_seconds)
  if timeout_value == nil or timeout_value < 0 then
    return nil, "timeout_seconds must be a non-negative number"
  end

  local removed = {}
  for session_id, session in pairs(sessions) do
    local reference_epoch = to_number(session.lastModifiedAtEpoch) or to_number(session.createdAtEpoch)
    if reference_epoch ~= nil and (now_value - reference_epoch) > timeout_value then
      sessions[session_id] = nil
      removed[#removed + 1] = session_id
    end
  end
  table.sort(removed)
  return removed, nil
end

function placement_session_service.reset()
  sessions = {}
end

return placement_session_service
