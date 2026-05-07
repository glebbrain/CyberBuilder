local placement_request_validator = {}

local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local sep = package.config:sub(1, 1)
local category_filter = dofile(this_dir() .. ".." .. sep .. "construction_chip" .. sep .. "category_filter.lua")

placement_request_validator.SAFE_PLACEMENT_TAGS = {
  buildable = true,
  safe = true,
  decor = true,
  static = true,
  owned = true,
}

placement_request_validator.FORBIDDEN_PLACEMENT_TAGS = {
  quest = true,
  npc = true,
  vehicle = true,
  combat = true,
  physics = true,
  story = true,
  critical = true,
}

placement_request_validator.BLOCKED_REASON_CODES = {
  unsafe_category = "unsafe_category",
  forbidden_tag = "forbidden_tag",
  missing_authorization = "missing_authorization",
  stale_authorization = "stale_authorization",
  disabled_object = "disabled_object",
  provider_unavailable = "provider_unavailable",
}

local function push(errs, msg)
  errs[#errs + 1] = msg
end

local function is_non_empty_string(v)
  return type(v) == "string" and v:find("%S") ~= nil
end

local function is_number(v)
  return type(v) == "number"
end

local function is_finite_number(v)
  return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function normalize_id(v)
  if type(v) ~= "string" then
    return ""
  end
  return (v:match("^%s*(.-)%s*$") or "")
end

local function normalize_tag(v)
  if type(v) ~= "string" then
    return ""
  end
  return (v:match("^%s*(.-)%s*$") or ""):lower()
end

local function validate_vec3(name, value, errs)
  if type(value) ~= "table" then
    push(errs, string.format("%s: expected object", name))
    return
  end
  if not is_number(value.x) then
    push(errs, string.format("%s.x: expected number", name))
  end
  if not is_number(value.y) then
    push(errs, string.format("%s.y: expected number", name))
  end
  if not is_number(value.z) then
    push(errs, string.format("%s.z: expected number", name))
  end
end

local function validate_rotation(name, value, errs)
  if type(value) ~= "table" then
    push(errs, string.format("%s: expected object", name))
    return
  end
  if not is_number(value.pitch) then
    push(errs, string.format("%s.pitch: expected number", name))
  end
  if not is_number(value.yaw) then
    push(errs, string.format("%s.yaw: expected number", name))
  end
  if not is_number(value.roll) then
    push(errs, string.format("%s.roll: expected number", name))
  end
end

local function validate_tags(value, errs)
  if type(value) ~= "table" then
    push(errs, "tags: expected array of strings")
    return
  end
  for i, tag in ipairs(value) do
    if type(tag) ~= "string" then
      push(errs, string.format("tags[%d]: expected string", i))
    end
  end
end

--- Validate placement request payload shape and basic value constraints.
--- Returns `true, nil` or `false, { "error", ... }`.
function placement_request_validator.validate_request(request)
  local errs = {}
  if type(request) ~= "table" then
    return false, { "request: expected object" }
  end

  for _, key in ipairs({
    "requestId",
    "sessionId",
    "ownerId",
    "packId",
    "objectId",
    "globalId",
    "provider",
    "position",
    "rotation",
    "scale",
    "tags",
    "requestedAt",
  }) do
    if request[key] == nil then
      push(errs, string.format("request: missing required field %q", key))
    end
  end

  if request.requestId ~= nil and not is_non_empty_string(request.requestId) then
    push(errs, "requestId: expected non-empty string")
  end
  if request.sessionId ~= nil and not is_non_empty_string(request.sessionId) then
    push(errs, "sessionId: expected non-empty string")
  end
  if request.ownerId ~= nil and not is_non_empty_string(request.ownerId) then
    push(errs, "ownerId: expected non-empty string")
  end
  if request.packId ~= nil and not is_non_empty_string(request.packId) then
    push(errs, "packId: expected non-empty string")
  end
  if request.objectId ~= nil and not is_non_empty_string(request.objectId) then
    push(errs, "objectId: expected non-empty string")
  end
  if request.globalId ~= nil and not is_non_empty_string(request.globalId) then
    push(errs, "globalId: expected non-empty string")
  end
  if request.provider ~= nil and not is_non_empty_string(request.provider) then
    push(errs, "provider: expected non-empty string")
  end
  if request.requestedAt ~= nil and not is_non_empty_string(request.requestedAt) then
    push(errs, "requestedAt: expected non-empty string")
  end

  if request.position ~= nil then
    validate_vec3("position", request.position, errs)
  end
  if request.rotation ~= nil then
    validate_rotation("rotation", request.rotation, errs)
  end
  if request.scale ~= nil then
    if type(request.scale) ~= "number" then
      push(errs, "scale: expected number")
    elseif request.scale < 0.1 or request.scale > 3.0 then
      push(errs, "scale: must be within range 0.1..3.0")
    end
  end
  if request.tags ~= nil then
    validate_tags(request.tags, errs)
  end

  if #errs == 0 then
    return true, nil
  end
  return false, errs
end

--- Validate that request object identity is present in authorized build catalog entries.
--- `authorized_entries` must be an array of entries with (`globalId`) or (`packId`,`objectId`).
--- Returns `true, nil` or `false, "error"`.
function placement_request_validator.validate_authorized_catalog_membership(request, authorized_entries)
  if type(request) ~= "table" then
    return false, "request: expected object"
  end
  if type(authorized_entries) ~= "table" then
    return false, "authorized_entries: expected array table"
  end

  local request_global_id = normalize_id(request.globalId)
  local request_pack_id = normalize_id(request.packId)
  local request_object_id = normalize_id(request.objectId)

  if request_global_id == "" and (request_pack_id == "" or request_object_id == "") then
    return false, "request must provide globalId or (packId and objectId)"
  end

  for _, entry in ipairs(authorized_entries) do
    if type(entry) == "table" then
      local entry_global_id = normalize_id(entry.globalId)
      if request_global_id ~= "" and entry_global_id == request_global_id then
        return true, nil
      end

      local entry_pack_id = normalize_id(entry.packId)
      local entry_object_id = normalize_id(entry.objectId)
      if request_pack_id ~= "" and request_object_id ~= "" then
        if entry_pack_id == request_pack_id and entry_object_id == request_object_id then
          return true, nil
        end
      end
    end
  end

  return false, "requested object is not present in authorized build catalog"
end

--- Validate object category is allowlisted for placement.
--- Returns `true, nil` or `false, "error"`.
function placement_request_validator.validate_category_allowlist(category, allowlist)
  local rules = type(allowlist) == "table" and allowlist or category_filter.ALLOWLIST_CATEGORIES
  if not category_filter.is_allowed(category, rules) then
    return false, "object category is not in placement allowlist"
  end
  return true, nil
end

--- Validate object category is not denylisted for placement.
--- Returns `true, nil` or `false, "error"`.
function placement_request_validator.validate_category_denylist(category, denylist)
  local rules = type(denylist) == "table" and denylist or category_filter.DENYLIST_CATEGORIES
  if category_filter.is_denied(category, rules) then
    return false, "object category matches placement denylist"
  end
  return true, nil
end

--- Validate object is not disabled for placement.
--- Accepts either full object entry (`object.disabled`) or boolean flag.
--- Returns `true, nil` or `false, "error"`.
function placement_request_validator.validate_not_disabled(object_or_disabled_flag)
  local disabled
  if type(object_or_disabled_flag) == "table" then
    disabled = object_or_disabled_flag.disabled == true
  else
    disabled = object_or_disabled_flag == true
  end
  if disabled then
    return false, "disabled object cannot be placed"
  end
  return true, nil
end

--- Validate transform values are numeric and finite.
--- Returns `true, nil` or `false, { "error", ... }`.
function placement_request_validator.validate_transform_numeric_ranges(transform)
  local errs = {}
  if type(transform) ~= "table" then
    return false, { "transform: expected object" }
  end

  local position = transform.position
  local rotation = transform.rotation
  local scale = transform.scale

  if type(position) ~= "table" then
    push(errs, "position: expected object")
  else
    if not is_finite_number(position.x) then
      push(errs, "position.x: expected finite number")
    end
    if not is_finite_number(position.y) then
      push(errs, "position.y: expected finite number")
    end
    if not is_finite_number(position.z) then
      push(errs, "position.z: expected finite number")
    end
  end

  if type(rotation) ~= "table" then
    push(errs, "rotation: expected object")
  else
    if not is_finite_number(rotation.pitch) then
      push(errs, "rotation.pitch: expected finite number")
    end
    if not is_finite_number(rotation.yaw) then
      push(errs, "rotation.yaw: expected finite number")
    end
    if not is_finite_number(rotation.roll) then
      push(errs, "rotation.roll: expected finite number")
    end
  end

  if not is_finite_number(scale) then
    push(errs, "scale: expected finite number")
  end

  if #errs == 0 then
    return true, nil
  end
  return false, errs
end

--- Validate placement scale range.
--- Returns `true, nil` or `false, "error"`.
function placement_request_validator.validate_scale_range(scale)
  if not is_finite_number(scale) then
    return false, "scale must be a finite number"
  end
  if scale < 0.1 or scale > 3.0 then
    return false, "scale must satisfy 0.1 <= scale <= 3.0"
  end
  return true, nil
end

--- Validate rotation is normalized to 0..360 degrees.
--- Accepts `{ pitch, yaw, roll }`.
--- Returns `true, nil` or `false, "error"`.
function placement_request_validator.validate_rotation_normalization(rotation)
  if type(rotation) ~= "table" then
    return false, "rotation must be an object"
  end
  for _, key in ipairs({ "pitch", "yaw", "roll" }) do
    local value = rotation[key]
    if not is_finite_number(value) then
      return false, string.format("rotation.%s must be a finite number", key)
    end
    if value < 0 or value > 360 then
      return false, string.format("rotation.%s must be within 0..360 degrees", key)
    end
  end
  return true, nil
end

--- Validate position vector has complete numeric components.
--- Accepts `{ x, y, z }`.
--- Returns `true, nil` or `false, "error"`.
function placement_request_validator.validate_position_vector_completeness(position)
  if type(position) ~= "table" then
    return false, "position must be an object"
  end
  for _, key in ipairs({ "x", "y", "z" }) do
    if not is_finite_number(position[key]) then
      return false, string.format("position.%s must be a finite number", key)
    end
  end
  return true, nil
end

--- Validate tags are within safe placement tag set.
--- Returns `true, nil` or `false, "error"`.
function placement_request_validator.validate_safe_placement_tags(tags, safe_tag_set)
  if type(tags) ~= "table" then
    return false, "tags must be an array table"
  end
  local allowed = type(safe_tag_set) == "table" and safe_tag_set or placement_request_validator.SAFE_PLACEMENT_TAGS

  for i, tag in ipairs(tags) do
    local normalized = normalize_tag(tag)
    if normalized == "" then
      return false, string.format("tags[%d] must be a non-empty string", i)
    end
    if allowed[normalized] ~= true then
      return false, string.format("tags[%d]=%q is not a safe placement tag", i, normalized)
    end
  end
  return true, nil
end

--- Validate tags do not include forbidden placement tags.
--- Returns `true, nil` or `false, "error"`.
function placement_request_validator.validate_forbidden_placement_tags(tags, forbidden_tag_set)
  if type(tags) ~= "table" then
    return false, "tags must be an array table"
  end
  local forbidden = type(forbidden_tag_set) == "table" and forbidden_tag_set
    or placement_request_validator.FORBIDDEN_PLACEMENT_TAGS

  for i, tag in ipairs(tags) do
    local normalized = normalize_tag(tag)
    if normalized ~= "" and forbidden[normalized] == true then
      return false, string.format("tags[%d]=%q is a forbidden placement tag", i, normalized)
    end
  end
  return true, nil
end

function placement_request_validator.get_blocked_reason_code(reason_key)
  local key = normalize_id(reason_key)
  if key == "" then
    return nil, "reason_key must be a non-empty string"
  end
  local code = placement_request_validator.BLOCKED_REASON_CODES[key]
  if code == nil then
    return nil, "unknown blocked reason key"
  end
  return code, nil
end

return placement_request_validator
