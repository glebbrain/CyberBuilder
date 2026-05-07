local chip_state = {}

local DEFAULT_STATE = {
  chipState = "missing",
}

local runtime_state = {
  chipState = DEFAULT_STATE.chipState,
}

local VALID_STATES = {
  missing = true,
  installed = true,
  active = true,
  restricted = true,
}

local function trim(s)
  if type(s) ~= "string" then
    return ""
  end
  return (s:match("^%s*(.-)%s*$") or "")
end

function chip_state.get()
  return {
    chipState = runtime_state.chipState,
  }
end

function chip_state.get_value()
  return runtime_state.chipState
end

function chip_state.set(next_state)
  local normalized = trim(next_state)
  if normalized == "" then
    return false, "chip state must be a non-empty string"
  end
  if not VALID_STATES[normalized] then
    return false, "chip state must be one of: missing, installed, active, restricted"
  end
  runtime_state.chipState = normalized
  return true, nil
end

function chip_state.reset()
  runtime_state.chipState = DEFAULT_STATE.chipState
  return chip_state.get()
end

return chip_state
