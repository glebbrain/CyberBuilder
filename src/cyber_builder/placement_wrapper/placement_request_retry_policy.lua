local placement_request_retry_policy = {}

placement_request_retry_policy.DEFAULT_MAX_RETRIES = 2
placement_request_retry_policy.DEFAULT_BASE_DELAY_SECONDS = 1
placement_request_retry_policy.DEFAULT_MAX_DELAY_SECONDS = 8

local RETRIABLE_PROVIDER_STATES = {
  missing = true,
  disabled = false,
  unsupported_version = false,
  runtime_error = true,
}

local function to_number(v, fallback)
  local n = tonumber(v)
  if n == nil then
    return fallback
  end
  return n
end

-- True when provider failure is eligible for retry.
function placement_request_retry_policy.is_retriable_provider_failure(provider_state)
  if type(provider_state) ~= "string" then
    return false
  end
  return RETRIABLE_PROVIDER_STATES[provider_state] == true
end

-- Decide whether retry should be attempted.
function placement_request_retry_policy.should_retry(attempt_count, provider_state, max_retries)
  local attempts = to_number(attempt_count, 0)
  local max_attempts = to_number(max_retries, placement_request_retry_policy.DEFAULT_MAX_RETRIES)
  if attempts < 0 then
    attempts = 0
  end
  if max_attempts < 0 then
    max_attempts = 0
  end
  if attempts >= max_attempts then
    return false
  end
  return placement_request_retry_policy.is_retriable_provider_failure(provider_state)
end

-- Exponential backoff delay (seconds) for retry scheduling.
function placement_request_retry_policy.next_delay_seconds(attempt_count, base_delay_seconds, max_delay_seconds)
  local attempt = to_number(attempt_count, 0)
  local base_delay = to_number(base_delay_seconds, placement_request_retry_policy.DEFAULT_BASE_DELAY_SECONDS)
  local max_delay = to_number(max_delay_seconds, placement_request_retry_policy.DEFAULT_MAX_DELAY_SECONDS)
  if attempt < 0 then
    attempt = 0
  end
  if base_delay < 0 then
    base_delay = placement_request_retry_policy.DEFAULT_BASE_DELAY_SECONDS
  end
  if max_delay < 0 then
    max_delay = placement_request_retry_policy.DEFAULT_MAX_DELAY_SECONDS
  end

  local delay = base_delay * (2 ^ attempt)
  if delay > max_delay then
    delay = max_delay
  end
  return delay
end

return placement_request_retry_policy
