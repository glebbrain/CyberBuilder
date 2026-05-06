-- Manual structural validation for decoded pack.json / objects.json / recipes.json tables.
-- Matches required fields and core types from `schemas/*.schema.json` (not cross-field rules).
local schema_validator = {}

local OBJECT_TYPES = {
  entity = true,
  mesh = true,
  decal = true,
  light = true,
  sound = true,
}

local function push(errs, msg)
  errs[#errs + 1] = msg
end

local function is_integer_key(k)
  return type(k) == "number" and k >= 1 and math.floor(k) == k
end

--- True when `t` is a JSON-like dense array (only integer keys 1..n).
local function is_dense_array(t)
  if type(t) ~= "table" then
    return false
  end
  local n = 0
  for k in pairs(t) do
    if not is_integer_key(k) then
      return false
    end
    if k > n then
      n = k
    end
  end
  for i = 1, n do
    if t[i] == nil then
      return false
    end
  end
  return true
end

--- Returns `true, nil` or `false, { "error", ... }`.
function schema_validator.validate_pack(pack)
  local errs = {}
  if type(pack) ~= "table" then
    return false, { "pack: expected object (table)" }
  end
  local req = { "id", "name", "version", "author", "requires" }
  for _, key in ipairs(req) do
    if pack[key] == nil then
      push(errs, string.format("pack: missing required field %q", key))
    end
  end
  if #errs > 0 then
    return false, errs
  end
  for _, key in ipairs({ "id", "name", "version", "author" }) do
    if type(pack[key]) ~= "string" then
      push(errs, string.format("pack.%s: expected string", key))
    end
  end
  if type(pack.id) == "string" then
    if pack.id == "" then
      push(errs, "pack.id: must be a non-empty lowercase slug")
    elseif not pack.id:match("^[a-z0-9_-]+$") then
      push(errs, "pack.id: must use only lowercase letters, digits, underscore, and dash")
    end
  end
  if not is_dense_array(pack.requires) then
    push(errs, "pack.requires: expected array of strings")
  else
    for i, v in ipairs(pack.requires) do
      if type(v) ~= "string" then
        push(errs, string.format("pack.requires[%d]: expected string", i))
      end
    end
  end
  if #errs == 0 then
    return true, nil
  end
  return false, errs
end

--- Returns `true, nil` or `false, { "error", ... }`.
function schema_validator.validate_objects(objects)
  local errs = {}
  if not is_dense_array(objects) then
    return false, { "objects: expected array" }
  end
  local ids_seen = {}
  for idx, obj in ipairs(objects) do
    local prefix = string.format("objects[%d]", idx)
    if type(obj) ~= "table" then
      push(errs, prefix .. ": expected object")
    else
      local fields = {
        "id",
        "name",
        "type",
        "resourcePath",
        "category",
        "price",
        "tags",
        "buildable",
        "deletable",
      }
      for _, key in ipairs(fields) do
        if obj[key] == nil then
          push(errs, string.format("%s: missing required field %q", prefix, key))
        end
      end
      if obj.id ~= nil and type(obj.id) ~= "string" then
        push(errs, prefix .. ".id: expected string")
      end
      if obj.name ~= nil and type(obj.name) ~= "string" then
        push(errs, prefix .. ".name: expected string")
      end
      if obj.type ~= nil and type(obj.type) ~= "string" then
        push(errs, prefix .. ".type: expected string")
      elseif type(obj.type) == "string" and not OBJECT_TYPES[obj.type] then
        push(errs, prefix .. ".type: must be entity, mesh, decal, light, or sound")
      end
      if obj.resourcePath ~= nil and type(obj.resourcePath) ~= "string" then
        push(errs, prefix .. ".resourcePath: expected string")
      elseif type(obj.resourcePath) == "string" and obj.disabled ~= true then
        if obj.resourcePath:find("%S") == nil then
          push(errs, prefix .. ".resourcePath: must be non-empty for enabled objects")
        end
      end
      if obj.category ~= nil and type(obj.category) ~= "string" then
        push(errs, prefix .. ".category: expected string")
      end
      if obj.price ~= nil and type(obj.price) ~= "number" then
        push(errs, prefix .. ".price: expected number")
      end
      if obj.tags ~= nil then
        if not is_dense_array(obj.tags) then
          push(errs, prefix .. ".tags: expected array of strings")
        else
          for ti, tv in ipairs(obj.tags) do
            if type(tv) ~= "string" then
              push(errs, string.format("%s.tags[%d]: expected string", prefix, ti))
            end
          end
        end
      end
      if obj.buildable ~= nil and type(obj.buildable) ~= "boolean" then
        push(errs, prefix .. ".buildable: expected boolean")
      end
      if obj.deletable ~= nil and type(obj.deletable) ~= "boolean" then
        push(errs, prefix .. ".deletable: expected boolean")
      end
      if obj.disabled ~= nil and type(obj.disabled) ~= "boolean" then
        push(errs, prefix .. ".disabled: expected boolean")
      end
      if type(obj.id) == "string" then
        local first = ids_seen[obj.id]
        if first ~= nil then
          push(
            errs,
            string.format("%s.id: duplicate object id %q (first at objects[%d])", prefix, obj.id, first)
          )
        else
          ids_seen[obj.id] = idx
        end
      end
    end
  end
  if #errs == 0 then
    return true, nil
  end
  return false, errs
end

--- Returns `true, nil` or `false, { "error", ... }`.
-- If `objects` is the decoded `objects.json` array, each recipe `objectId` must exist on some object `id`.
function schema_validator.validate_recipes(recipes, objects)
  local errs = {}
  if not is_dense_array(recipes) then
    return false, { "recipes: expected array" }
  end
  local object_ids
  if objects ~= nil then
    if not is_dense_array(objects) then
      return false, { "recipes: objects catalog must be a dense array for objectId lookup" }
    end
    object_ids = {}
    for _, obj in ipairs(objects) do
      if type(obj) == "table" and type(obj.id) == "string" then
        object_ids[obj.id] = true
      end
    end
  end
  for idx, rec in ipairs(recipes) do
    local prefix = string.format("recipes[%d]", idx)
    if type(rec) ~= "table" then
      push(errs, prefix .. ": expected object")
    else
      for _, key in ipairs({ "objectId", "components", "seconds" }) do
        if rec[key] == nil then
          push(errs, string.format("%s: missing required field %q", prefix, key))
        end
      end
      if rec.objectId ~= nil and type(rec.objectId) ~= "string" then
        push(errs, prefix .. ".objectId: expected string")
      end
      if rec.components ~= nil and not is_dense_array(rec.components) then
        push(errs, prefix .. ".components: expected array")
      end
      if rec.seconds ~= nil and type(rec.seconds) ~= "number" then
        push(errs, prefix .. ".seconds: expected number")
      end
      if object_ids ~= nil and type(rec.objectId) == "string" then
        if not object_ids[rec.objectId] then
          push(
            errs,
            string.format("%s.objectId: unknown object id %q (not in objects.json)", prefix, rec.objectId)
          )
        end
      end
    end
  end
  if #errs == 0 then
    return true, nil
  end
  return false, errs
end

return schema_validator
