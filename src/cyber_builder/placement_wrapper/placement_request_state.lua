local placement_request_state = {}

placement_request_state.STATES = {
  pending = "pending",
  validated = "validated",
  delegated = "delegated",
  placed = "placed",
  failed = "failed",
  removed = "removed",
}

local VALID_STATES = {
  [placement_request_state.STATES.pending] = true,
  [placement_request_state.STATES.validated] = true,
  [placement_request_state.STATES.delegated] = true,
  [placement_request_state.STATES.placed] = true,
  [placement_request_state.STATES.failed] = true,
  [placement_request_state.STATES.removed] = true,
}

local TRANSITIONS = {
  [placement_request_state.STATES.pending] = {
    [placement_request_state.STATES.validated] = true,
    [placement_request_state.STATES.failed] = true,
  },
  [placement_request_state.STATES.validated] = {
    [placement_request_state.STATES.delegated] = true,
    [placement_request_state.STATES.failed] = true,
  },
  [placement_request_state.STATES.delegated] = {
    [placement_request_state.STATES.placed] = true,
    [placement_request_state.STATES.failed] = true,
  },
  [placement_request_state.STATES.placed] = {
    [placement_request_state.STATES.removed] = true,
    [placement_request_state.STATES.failed] = true,
  },
  [placement_request_state.STATES.failed] = {},
  [placement_request_state.STATES.removed] = {},
}

function placement_request_state.is_valid(state)
  return VALID_STATES[state] == true
end

function placement_request_state.can_transition(from_state, to_state)
  if not placement_request_state.is_valid(from_state) then
    return false
  end
  if not placement_request_state.is_valid(to_state) then
    return false
  end
  return TRANSITIONS[from_state][to_state] == true
end

function placement_request_state.transition(current_state, next_state)
  if not placement_request_state.is_valid(current_state) then
    return nil, "invalid current state"
  end
  if not placement_request_state.is_valid(next_state) then
    return nil, "invalid next state"
  end
  if not placement_request_state.can_transition(current_state, next_state) then
    return nil, "invalid state transition"
  end
  return next_state, nil
end

return placement_request_state
