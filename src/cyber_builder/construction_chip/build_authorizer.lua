local build_authorizer = {}

build_authorizer.SAFE_TAGS = {
  buildable = true,
  safe = true,
  decor = true,
  static = true,
}

build_authorizer.FORBIDDEN_TAGS = {
  quest = true,
  npc = true,
  vehicle = true,
  combat = true,
  physics = true,
  story = true,
}

local cache_state = {
  registry_signature = nil,
  authorized_entries = nil,
}

local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local sep = package.config:sub(1, 1)
local path_utils = dofile(this_dir() .. ".." .. sep .. "path_utils.lua")
local category_filter = dofile(this_dir() .. "category_filter.lua")

local function trim(s)
  if type(s) ~= "string" then
    return ""
  end
  return (s:match("^%s*(.-)%s*$") or "")
end

local function normalize_id(v)
  return trim(v)
end

local function normalize_text(v)
  return trim(type(v) == "string" and v:lower() or "")
end

local function normalize_tag(v)
  return trim(type(v) == "string" and v:lower() or "")
end

local function has_safe_tag(tags)
  if type(tags) ~= "table" then
    return false
  end
  for _, tag in ipairs(tags) do
    local normalized = normalize_tag(tag)
    if normalized ~= "" and build_authorizer.SAFE_TAGS[normalized] then
      return true
    end
  end
  return false
end

local function has_forbidden_tag(tags)
  if type(tags) ~= "table" then
    return false
  end
  for _, tag in ipairs(tags) do
    local normalized = normalize_tag(tag)
    if normalized ~= "" and build_authorizer.FORBIDDEN_TAGS[normalized] then
      return true
    end
  end
  return false
end

local function json_escape(s)
  return s:gsub('[%z\1-\31\\"]', function(c)
    local map = {
      ['"'] = '\\"',
      ["\\"] = "\\\\",
      ["\b"] = "\\b",
      ["\f"] = "\\f",
      ["\n"] = "\\n",
      ["\r"] = "\\r",
      ["\t"] = "\\t",
    }
    return map[c] or string.format("\\u%04x", c:byte())
  end)
end

local function json_encode(v)
  local t = type(v)
  if t == "nil" then
    return "null"
  end
  if t == "boolean" then
    return v and "true" or "false"
  end
  if t == "number" then
    return string.format("%.14g", v)
  end
  if t == "string" then
    return '"' .. json_escape(v) .. '"'
  end
  if t ~= "table" then
    error("unsupported json type: " .. t)
  end
  if #v > 0 then
    local arr = {}
    for i = 1, #v do
      arr[#arr + 1] = json_encode(v[i])
    end
    return "[" .. table.concat(arr, ",") .. "]"
  end
  local keys = {}
  for k in pairs(v) do
    if type(k) == "string" then
      keys[#keys + 1] = k
    end
  end
  table.sort(keys)
  local obj = {}
  for _, k in ipairs(keys) do
    obj[#obj + 1] = json_encode(k) .. ":" .. json_encode(v[k])
  end
  return "{" .. table.concat(obj, ",") .. "}"
end

local function ensure_parent_dir(file_path)
  local parent = file_path:match("^(.*)[/\\][^/\\]+$")
  if not parent or parent == "" then
    return
  end
  if package.config:sub(1, 1) == "\\" then
    os.execute('cmd /c mkdir "' .. parent:gsub("/", "\\"):gsub('"', "") .. '" 2>nul')
  end
end

local function build_entry(obj, pack_id)
  local object_id = normalize_id(type(obj) == "table" and obj.id or nil)
  if object_id == "" then
    return nil, "object id is required"
  end

  local normalized_pack_id = normalize_id(pack_id)
  if normalized_pack_id == "" then
    return nil, "pack_id is required"
  end

  return {
    packId = normalized_pack_id,
    objectId = object_id,
    globalId = normalized_pack_id .. ":" .. object_id,
    name = type(obj.name) == "string" and obj.name or "",
    type = type(obj.type) == "string" and obj.type or "",
    resourcePath = type(obj.resourcePath) == "string" and obj.resourcePath or "",
    category = type(obj.category) == "string" and obj.category or "",
    tags = type(obj.tags) == "table" and obj.tags or {},
    price = type(obj.price) == "number" and obj.price or 0,
    components = type(obj.components) == "table" and obj.components or {},
    craftSeconds = type(obj.craftSeconds) == "number" and obj.craftSeconds or 0,
    vendorTier = type(obj.vendorTier) == "string" and obj.vendorTier or "",
    placementType = type(obj.placementType) == "string" and obj.placementType or "",
    snapPoints = type(obj.snapPoints) == "table" and obj.snapPoints or {},
    rotationMode = type(obj.rotationMode) == "string" and obj.rotationMode or "",
    dlcDependencies = type(obj.dlcDependencies) == "table" and obj.dlcDependencies or {},
    communityPackDependencies = type(obj.communityPackDependencies) == "table" and obj.communityPackDependencies or {},
    factionOwnership = type(obj.factionOwnership) == "string" and obj.factionOwnership or "",
    vendorOwnership = type(obj.vendorOwnership) == "string" and obj.vendorOwnership or "",
    authorized = true,
  }, nil
end

function build_authorizer.authorize_object(obj, pack_id)
  if type(obj) ~= "table" then
    return nil, "obj must be a table"
  end
  if obj.disabled == true then
    return nil, "disabled object cannot be authorized"
  end
  if has_forbidden_tag(obj.tags) then
    return nil, "object contains forbidden tag"
  end
  if not has_safe_tag(obj.tags) then
    return nil, "object must contain at least one safe tag"
  end
  local cat = type(obj.category) == "string" and obj.category or ""
  if category_filter.is_denied(cat, category_filter.DENYLIST_CATEGORIES) then
    return nil, "category is denylisted for gameplay authorization"
  end
  if not category_filter.is_allowed(cat, category_filter.ALLOWLIST_CATEGORIES) then
    return nil, "category is not allowlisted for gameplay authorization"
  end
  return build_entry(obj, pack_id)
end

function build_authorizer.authorize_objects(objects, pack_id)
  if type(objects) ~= "table" then
    return nil, "objects must be an array table"
  end

  local out = {}
  for _, obj in ipairs(objects) do
    local entry = build_authorizer.authorize_object(obj, pack_id)
    if entry then
      out[#out + 1] = entry
    end
  end
  return out, nil
end

function build_authorizer.validate_disabled_objects_not_authorized(source_objects, authorized_entries)
  if type(source_objects) ~= "table" then
    return nil, "source_objects must be an array table"
  end
  if type(authorized_entries) ~= "table" then
    return nil, "authorized_entries must be an array table"
  end

  local disabled_ids = {}
  for _, obj in ipairs(source_objects) do
    if type(obj) == "table" and obj.disabled == true then
      local id = normalize_id(obj.id)
      if id ~= "" then
        disabled_ids[id] = true
      end
    end
  end

  for i, entry in ipairs(authorized_entries) do
    if type(entry) == "table" then
      local object_id = normalize_id(entry.objectId)
      if object_id ~= "" and disabled_ids[object_id] then
        return false, string.format(
          "disabled object %q appears in authorized entries at index %d",
          object_id,
          i
        )
      end
    end
  end

  return true, nil
end

function build_authorizer.generate_from_valid_packs(validated_packs)
  if type(validated_packs) ~= "table" then
    return nil, "validated_packs must be an array table"
  end

  local authorized = {}
  for _, pack_entry in ipairs(validated_packs) do
    if type(pack_entry) == "table" then
      local is_valid = pack_entry.isValid == true or pack_entry.valid == true
      if is_valid then
        local pack = type(pack_entry.pack) == "table" and pack_entry.pack or {}
        local pack_id = normalize_id(pack.id)
        local objects = type(pack_entry.objects) == "table" and pack_entry.objects or {}
        local entries, err = build_authorizer.authorize_objects(objects, pack_id)
        if not entries then
          return nil, err
        end
        for _, entry in ipairs(entries) do
          authorized[#authorized + 1] = entry
        end
      end
    end
  end

  return build_authorizer.sort_authorized_entries(authorized)
end

function build_authorizer.sort_authorized_entries(entries)
  if type(entries) ~= "table" then
    return nil, "entries must be an array table"
  end

  local out = {}
  for i = 1, #entries do
    out[i] = entries[i]
  end

  table.sort(out, function(a, b)
    local a_category = normalize_text(type(a) == "table" and a.category or "")
    local b_category = normalize_text(type(b) == "table" and b.category or "")
    if a_category ~= b_category then
      return a_category < b_category
    end

    local a_name = normalize_text(type(a) == "table" and a.name or "")
    local b_name = normalize_text(type(b) == "table" and b.name or "")
    if a_name ~= b_name then
      return a_name < b_name
    end

    local a_global = normalize_text(type(a) == "table" and a.globalId or "")
    local b_global = normalize_text(type(b) == "table" and b.globalId or "")
    return a_global < b_global
  end)

  return out, nil
end

function build_authorizer.rebuild_cache_if_registry_changed(registry_signature, validated_packs)
  local signature = trim(registry_signature)
  if signature == "" then
    return nil, "registry_signature must be a non-empty string"
  end

  local changed = cache_state.registry_signature ~= signature
  if changed then
    local authorized, err = build_authorizer.generate_from_valid_packs(validated_packs)
    if not authorized then
      return nil, err
    end
    cache_state.registry_signature = signature
    cache_state.authorized_entries = authorized
  end

  return {
    changed = changed,
    registrySignature = cache_state.registry_signature,
    authorizedEntries = cache_state.authorized_entries or {},
  }, nil
end

function build_authorizer.clear_cache()
  cache_state.registry_signature = nil
  cache_state.authorized_entries = nil
end

function build_authorizer.export_authorization_file(entries, dist_dir)
  if type(entries) ~= "table" then
    return nil, "entries must be an array table"
  end
  if type(dist_dir) ~= "string" or dist_dir == "" then
    return nil, "dist_dir must be a non-empty string"
  end

  local out_path = path_utils.join(dist_dir, "build_authorization.json")
  local sorted, err = build_authorizer.sort_authorized_entries(entries)
  if not sorted then
    return nil, err
  end

  local ok, body = pcall(json_encode, sorted)
  if not ok then
    return nil, "cannot encode authorization entries as JSON"
  end

  ensure_parent_dir(out_path)
  local f, ferr = io.open(out_path, "wb")
  if not f then
    return nil, string.format("cannot write %q (%s)", out_path, tostring(ferr or "unknown"))
  end
  f:write(body)
  f:write("\n")
  f:close()
  return out_path, nil
end

function build_authorizer.export_blocked_objects_report(source_objects, authorized_entries, dist_dir)
  if type(source_objects) ~= "table" then
    return nil, "source_objects must be an array table"
  end
  if type(authorized_entries) ~= "table" then
    return nil, "authorized_entries must be an array table"
  end
  if type(dist_dir) ~= "string" or dist_dir == "" then
    return nil, "dist_dir must be a non-empty string"
  end

  local authorized_ids = {}
  for _, entry in ipairs(authorized_entries) do
    if type(entry) == "table" then
      local id = normalize_id(entry.objectId)
      if id ~= "" then
        authorized_ids[id] = true
      end
    end
  end

  local blocked = {}
  for _, obj in ipairs(source_objects) do
    if type(obj) == "table" then
      local id = normalize_id(obj.id)
      if id ~= "" and not authorized_ids[id] then
        blocked[#blocked + 1] = {
          objectId = id,
          name = type(obj.name) == "string" and obj.name or "",
          category = type(obj.category) == "string" and obj.category or "",
          disabled = obj.disabled == true,
          tags = type(obj.tags) == "table" and obj.tags or {},
        }
      end
    end
  end

  table.sort(blocked, function(a, b)
    return normalize_text(a.objectId) < normalize_text(b.objectId)
  end)

  local out_path = path_utils.join(dist_dir, "chip_blocked_objects.json")
  local ok, body = pcall(json_encode, blocked)
  if not ok then
    return nil, "cannot encode blocked objects report as JSON"
  end

  ensure_parent_dir(out_path)
  local f, err = io.open(out_path, "wb")
  if not f then
    return nil, string.format("cannot write %q (%s)", out_path, tostring(err or "unknown"))
  end
  f:write(body)
  f:write("\n")
  f:close()
  return out_path, nil
end

function build_authorizer.recover_missing_authorized_definitions(authorized_entries, source_objects, pack_id)
  if type(authorized_entries) ~= "table" then
    return nil, "authorized_entries must be an array table"
  end
  if type(source_objects) ~= "table" then
    return nil, "source_objects must be an array table"
  end
  local normalized_pack_id = normalize_id(pack_id)
  if normalized_pack_id == "" then
    return nil, "pack_id must be a non-empty string"
  end

  local source_by_id = {}
  for _, obj in ipairs(source_objects) do
    if type(obj) == "table" then
      local id = normalize_id(obj.id)
      if id ~= "" then
        source_by_id[id] = obj
      end
    end
  end

  local recovered = {}
  local recovered_count = 0
  local missing_count = 0

  for _, entry in ipairs(authorized_entries) do
    if type(entry) == "table" then
      local object_id = normalize_id(entry.objectId)
      local has_definition = normalize_text(entry.name) ~= ""
        and normalize_text(entry.resourcePath) ~= ""
        and normalize_text(entry.category) ~= ""

      if has_definition then
        recovered[#recovered + 1] = entry
      else
        local src = source_by_id[object_id]
        if type(src) == "table" then
          local rebuilt, err = build_entry(src, normalized_pack_id)
          if not rebuilt then
            return nil, err
          end
          recovered[#recovered + 1] = rebuilt
          recovered_count = recovered_count + 1
        else
          missing_count = missing_count + 1
        end
      end
    end
  end

  return {
    entries = recovered,
    recoveredCount = recovered_count,
    missingCount = missing_count,
  }, nil
end

return build_authorizer
