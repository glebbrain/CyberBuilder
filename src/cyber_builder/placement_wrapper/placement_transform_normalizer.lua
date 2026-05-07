local placement_transform_normalizer = {}

local function push(errs, msg)
  errs[#errs + 1] = msg
end

local function normalize_angle(value)
  local normalized = value % 360
  if normalized < 0 then
    normalized = normalized + 360
  end
  return normalized
end

local function validate_vec3(name, value, errs)
  if type(value) ~= "table" then
    push(errs, string.format("%s: expected object", name))
    return nil
  end
  if type(value.x) ~= "number" or type(value.y) ~= "number" or type(value.z) ~= "number" then
    push(errs, string.format("%s: x, y, z must be numbers", name))
    return nil
  end
  return {
    x = value.x,
    y = value.y,
    z = value.z,
  }
end

local function validate_rotation(value, errs)
  if type(value) ~= "table" then
    push(errs, "rotation: expected object")
    return nil
  end
  if type(value.pitch) ~= "number" or type(value.yaw) ~= "number" or type(value.roll) ~= "number" then
    push(errs, "rotation: pitch, yaw, roll must be numbers")
    return nil
  end
  return {
    pitch = value.pitch,
    yaw = value.yaw,
    roll = value.roll,
  }
end

--- Normalize placement transform fields into canonical runtime form.
--- Returns `normalizedTransform, nil` or `nil, { "error", ... }`.
function placement_transform_normalizer.normalize(transform)
  local errs = {}
  if type(transform) ~= "table" then
    return nil, { "transform: expected object" }
  end

  local position = validate_vec3("position", transform.position, errs)
  local rotation = validate_rotation(transform.rotation, errs)
  local scale = transform.scale

  if type(scale) ~= "number" then
    push(errs, "scale: expected number")
  end

  if #errs > 0 then
    return nil, errs
  end

  return {
    position = position,
    rotation = {
      pitch = normalize_angle(rotation.pitch),
      yaw = normalize_angle(rotation.yaw),
      roll = normalize_angle(rotation.roll),
    },
    scale = scale,
  }, nil
end

return placement_transform_normalizer
