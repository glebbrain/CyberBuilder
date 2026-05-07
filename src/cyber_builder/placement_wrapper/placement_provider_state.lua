local placement_provider_state = {}

placement_provider_state.STATES = {
  available = "available",
  missing = "missing",
  disabled = "disabled",
  unsupported_version = "unsupported_version",
  runtime_error = "runtime_error",
}

local VALID_STATES = {
  [placement_provider_state.STATES.available] = true,
  [placement_provider_state.STATES.missing] = true,
  [placement_provider_state.STATES.disabled] = true,
  [placement_provider_state.STATES.unsupported_version] = true,
  [placement_provider_state.STATES.runtime_error] = true,
}

function placement_provider_state.is_valid(state)
  return VALID_STATES[state] == true
end

function placement_provider_state.assert_valid(state)
  if placement_provider_state.is_valid(state) then
    return true, nil
  end
  return false, "invalid provider state"
end

return placement_provider_state
