local placement_provider_worldbuilder = {}

local PROVIDER_ID = "worldbuilder"
local PROVIDER_NAME = "World Builder"
local PROVIDER_VERSION = "v0.4"

local function is_non_empty_string(v)
  return type(v) == "string" and v:find("%S") ~= nil
end

local function copy_transform(transform)
  if type(transform) ~= "table" then
    return nil
  end
  local position = transform.position
  local rotation = transform.rotation
  if type(position) ~= "table" or type(rotation) ~= "table" then
    return nil
  end
  return {
    position = {
      x = position.x,
      y = position.y,
      z = position.z,
    },
    rotation = {
      pitch = rotation.pitch,
      yaw = rotation.yaw,
      roll = rotation.roll,
    },
    scale = transform.scale,
  }
end

local function build_future_metadata_hooks(request)
  return {
    snapGroup = request.snapGroup,
    placementSurface = request.placementSurface,
    powerRequirement = request.powerRequirement,
    collisionProfile = request.collisionProfile,
    interiorOnly = request.interiorOnly,
  }
end

local function build_future_streaming_hooks(request)
  return {
    cellId = request.cellId,
    streamingGroup = request.streamingGroup,
    loadRadius = request.loadRadius,
  }
end

local function build_future_multiplayer_hooks(request)
  return {
    networkSafe = request.networkSafe,
    shareable = request.shareable,
    sessionScoped = request.sessionScoped,
  }
end

function placement_provider_worldbuilder.get_provider_definition()
  return {
    id = PROVIDER_ID,
    name = PROVIDER_NAME,
    version = PROVIDER_VERSION,
    state = "available",
    capabilities = {
      supportsPlacement = true,
      supportsRemoval = true,
      supportsMove = false,
      supportsRotate = false,
      supportsPersistence = true,
    },
  }
end

function placement_provider_worldbuilder.to_place_payload(request)
  if type(request) ~= "table" then
    return nil, "request must be an object"
  end
  if not is_non_empty_string(request.requestId) then
    return nil, "request.requestId must be a non-empty string"
  end
  if not is_non_empty_string(request.globalId) then
    return nil, "request.globalId must be a non-empty string"
  end
  if not is_non_empty_string(request.ownerId) then
    return nil, "request.ownerId must be a non-empty string"
  end

  local transform = copy_transform(request.transform or {
    position = request.position,
    rotation = request.rotation,
    scale = request.scale,
  })
  if transform == nil then
    return nil, "request transform is invalid"
  end

  return {
    provider = PROVIDER_ID,
    operation = "place",
    requestId = request.requestId,
    sessionId = request.sessionId,
    ownerId = request.ownerId,
    globalId = request.globalId,
    packId = request.packId,
    objectId = request.objectId,
    transform = transform,
    tags = request.tags,
    metadataHooks = build_future_metadata_hooks(request),
    streamingHooks = build_future_streaming_hooks(request),
    multiplayerHooks = build_future_multiplayer_hooks(request),
  }, nil
end

-- Generate a World Builder export payload envelope from a placement request.
-- Returns `export_payload, nil` or `nil, "error"`.
function placement_provider_worldbuilder.generate_export_payload_for_request(request)
  local place_payload, payload_err = placement_provider_worldbuilder.to_place_payload(request)
  if place_payload == nil then
    return nil, payload_err
  end

  return {
    exportType = "worldbuilder_placement_request",
    exportVersion = "v0.4",
    provider = PROVIDER_ID,
    operation = "place",
    requestId = place_payload.requestId,
    sessionId = place_payload.sessionId,
    payload = place_payload,
  }, nil
end

function placement_provider_worldbuilder.to_remove_payload(removal_request)
  if type(removal_request) ~= "table" then
    return nil, "removal request must be an object"
  end
  if not is_non_empty_string(removal_request.requestId) then
    return nil, "removal requestId must be a non-empty string"
  end
  if not is_non_empty_string(removal_request.placementId) then
    return nil, "removal placementId must be a non-empty string"
  end
  if not is_non_empty_string(removal_request.ownerId) then
    return nil, "removal ownerId must be a non-empty string"
  end

  return {
    provider = PROVIDER_ID,
    operation = "remove",
    requestId = removal_request.requestId,
    sessionId = removal_request.sessionId,
    placementId = removal_request.placementId,
    ownerId = removal_request.ownerId,
  }, nil
end

return placement_provider_worldbuilder
