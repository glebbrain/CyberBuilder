local placement_provider_registry = {}

local VALID_STATES = {
  available = true,
  missing = true,
  disabled = true,
  unsupported_version = true,
  runtime_error = true,
}

local providers = {}

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

local function normalize_capabilities(input)
  local capabilities = {}
  local src = type(input) == "table" and input or {}
  capabilities.supportsPlacement = src.supportsPlacement == true
  capabilities.supportsRemoval = src.supportsRemoval == true
  capabilities.supportsMove = src.supportsMove == true
  capabilities.supportsRotate = src.supportsRotate == true
  capabilities.supportsPersistence = src.supportsPersistence == true
  return capabilities
end

local function parse_semver(version)
  if type(version) ~= "string" then
    return nil
  end
  local major, minor, patch = version:match("^v?(%d+)%.(%d+)%.(%d+)$")
  if not major then
    return nil
  end
  return {
    major = tonumber(major),
    minor = tonumber(minor),
    patch = tonumber(patch),
  }
end

local function compare_semver(a, b)
  if a.major ~= b.major then
    return a.major < b.major and -1 or 1
  end
  if a.minor ~= b.minor then
    return a.minor < b.minor and -1 or 1
  end
  if a.patch ~= b.patch then
    return a.patch < b.patch and -1 or 1
  end
  return 0
end

function placement_provider_registry.register(provider)
  if type(provider) ~= "table" then
    return nil, "provider must be an object"
  end
  if not is_non_empty_string(provider.id) then
    return nil, "provider.id must be a non-empty string"
  end
  if not is_non_empty_string(provider.name) then
    return nil, "provider.name must be a non-empty string"
  end
  if providers[provider.id] ~= nil then
    return nil, "provider already registered"
  end

  local state = provider.state or "available"
  if not VALID_STATES[state] then
    return nil, "provider.state is invalid"
  end

  local record = {
    id = provider.id,
    name = provider.name,
    version = provider.version,
    state = state,
    capabilities = normalize_capabilities(provider.capabilities),
  }
  providers[provider.id] = record
  return shallow_copy(record), nil
end

function placement_provider_registry.get(provider_id)
  local provider = providers[provider_id]
  if provider == nil then
    return nil
  end
  local result = shallow_copy(provider)
  result.capabilities = shallow_copy(provider.capabilities)
  return result
end

function placement_provider_registry.list()
  local ids = {}
  for provider_id in pairs(providers) do
    ids[#ids + 1] = provider_id
  end
  table.sort(ids)

  local out = {}
  for _, provider_id in ipairs(ids) do
    local provider = providers[provider_id]
    out[#out + 1] = {
      id = provider.id,
      name = provider.name,
      version = provider.version,
      state = provider.state,
      capabilities = shallow_copy(provider.capabilities),
    }
  end
  return out
end

function placement_provider_registry.set_state(provider_id, next_state)
  local provider = providers[provider_id]
  if provider == nil then
    return nil, "provider not found"
  end
  if not VALID_STATES[next_state] then
    return nil, "provider state is invalid"
  end
  provider.state = next_state
  return placement_provider_registry.get(provider_id), nil
end

function placement_provider_registry.is_available(provider_id)
  local provider = providers[provider_id]
  return provider ~= nil and provider.state == "available"
end

function placement_provider_registry.has_capability(provider_id, capability_name)
  local provider = providers[provider_id]
  if provider == nil then
    return false
  end
  return provider.capabilities[capability_name] == true
end

-- Discover provider capabilities with stable canonical keys.
-- Returns `capabilities, nil` or `nil, "error"`.
function placement_provider_registry.discover_capabilities(provider_id)
  local provider = providers[provider_id]
  if provider == nil then
    return nil, "provider not found"
  end
  local src = type(provider.capabilities) == "table" and provider.capabilities or {}
  return {
    supportsPlacement = src.supportsPlacement == true,
    supportsRemoval = src.supportsRemoval == true,
    supportsMove = src.supportsMove == true,
    supportsRotate = src.supportsRotate == true,
    supportsPersistence = src.supportsPersistence == true,
  }, nil
end

-- Check whether provider version is compatible with required range.
-- `required_min_version` and `required_max_version` are optional semver strings (e.g. "v0.4.0").
-- Returns `true, nil` or `false, "error"`.
function placement_provider_registry.check_version_compatibility(provider_id, required_min_version, required_max_version)
  local provider = providers[provider_id]
  if provider == nil then
    return false, "provider not found"
  end

  local provider_version = parse_semver(provider.version)
  if provider_version == nil then
    return false, "provider version is missing or invalid"
  end

  local min_version = parse_semver(required_min_version)
  if required_min_version ~= nil and min_version == nil then
    return false, "required_min_version must be semver"
  end
  local max_version = parse_semver(required_max_version)
  if required_max_version ~= nil and max_version == nil then
    return false, "required_max_version must be semver"
  end

  if min_version ~= nil and compare_semver(provider_version, min_version) < 0 then
    return false, "provider version is below supported minimum"
  end
  if max_version ~= nil and compare_semver(provider_version, max_version) > 0 then
    return false, "provider version is above supported maximum"
  end
  return true, nil
end

-- Health check for delegation readiness.
-- `required_capability` is optional (e.g. "supportsPlacement").
-- Returns `true, nil` or `false, "error"`.
function placement_provider_registry.check_health_before_delegation(provider_id, required_capability)
  local provider = providers[provider_id]
  if provider == nil then
    return false, "provider not found"
  end

  if provider.state ~= "available" then
    return false, "provider is not available"
  end

  if parse_semver(provider.version) == nil then
    return false, "provider version is missing or invalid"
  end

  if required_capability ~= nil and provider.capabilities[required_capability] ~= true then
    return false, "provider capability is not available"
  end

  return true, nil
end

function placement_provider_registry.reset()
  providers = {}
end

return placement_provider_registry
