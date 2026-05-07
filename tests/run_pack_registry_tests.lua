-- Simple Lua test runner: pack_registry, schema_validator, json_loader (no network, no game).
local TEST_DIR do
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  TEST_DIR = (s:gsub("[^/\\]+$", ""))
end

local function join_bootstrap(...)
  local sep = package.config:sub(1, 1)
  local parts = {}
  for i = 1, select("#", ...) do
    local p = select(i, ...)
    if type(p) == "string" and p ~= "" then
      parts[#parts + 1] = p
    end
  end
  if #parts == 0 then
    return ""
  end
  local acc = parts[1]
  for i = 2, #parts do
    acc = acc:gsub("[/\\]+$", "") .. sep .. parts[i]:gsub("^[/\\]+", "")
  end
  return acc
end

local path_utils = dofile(join_bootstrap(TEST_DIR, "..", "src", "cyber_builder", "path_utils.lua"))
local repo = path_utils.normalize(path_utils.join(TEST_DIR, ".."))
local cyber_dir = path_utils.join(repo, "src", "cyber_builder")
local pack_registry = dofile(path_utils.join(cyber_dir, "pack_registry.lua"))
local schema_validator = dofile(path_utils.join(cyber_dir, "schema_validator.lua"))
local json_loader = dofile(path_utils.join(cyber_dir, "json_loader.lua"))
local worldbuilder_exporter = dofile(path_utils.join(cyber_dir, "worldbuilder_exporter.lua"))
local catalog_service = dofile(path_utils.join(cyber_dir, "catalog_service.lua"))
local logger = dofile(path_utils.join(cyber_dir, "logger.lua"))
local category_filter = dofile(path_utils.join(cyber_dir, "construction_chip", "category_filter.lua"))
local build_authorizer = dofile(path_utils.join(cyber_dir, "construction_chip", "build_authorizer.lua"))
local chip_load_service = dofile(path_utils.join(cyber_dir, "construction_chip", "chip_load_service.lua"))
local unlock_registry = dofile(path_utils.join(cyber_dir, "construction_chip", "unlock_registry.lua"))
local catalog_projection = dofile(path_utils.join(cyber_dir, "construction_chip", "catalog_projection.lua"))
local player_progression = dofile(path_utils.join(cyber_dir, "construction_chip", "player_progression.lua"))

local failures = 0

local function fail(msg)
  io.stderr:write(msg .. "\n")
  failures = failures + 1
end

local function ok(name)
  print("[OK] " .. name)
end

local function assert_true(cond, name, detail)
  if not cond then
    fail(string.format("[FAIL] %s — %s", name, detail or "condition false"))
  else
    ok(name)
  end
end

-- pack_registry.discover on repo packs/
do
  local name = "pack_registry.discover(repo packs)"
  local packs_dir = path_utils.join(repo, "packs")
  local packs, err = pack_registry.discover(packs_dir)
  if packs == nil then
    fail(string.format("[FAIL] %s — %s", name, tostring(err)))
  else
    local ids = {}
    for _, e in ipairs(packs) do
      ids[e.id] = true
    end
    local have = ids["starter_furniture"] and ids["broken_example_pack"]
    assert_true(have, name, "expected starter_furniture and broken_example_pack in discover results")
  end
end

-- validate_pack: valid minimal pack
do
  local name = "schema_validator.validate_pack(valid)"
  local pack = {
    id = "good_pack",
    name = "Good",
    version = "1.0.0",
    author = "t",
    requires = { "world_builder" },
  }
  local pok, perrs = schema_validator.validate_pack(pack)
  assert_true(pok == true and perrs == nil, name, tostring(perrs))
end

-- catalog_service: generate catalog from valid starter pack
do
  local name = "catalog_service.from_validated_packs(valid starter pack)"
  local pack_root = path_utils.join(repo, "packs", "starter_furniture")
  local pack, pack_err = json_loader.read(path_utils.join(pack_root, "pack.json"))
  local objects, objects_err = json_loader.read(path_utils.join(pack_root, "objects.json"))
  local recipes, recipes_err = json_loader.read(path_utils.join(pack_root, "recipes.json"))
  if not pack or not objects or not recipes then
    fail(
      string.format(
        "[FAIL] %s — could not load starter pack files: pack=%s objects=%s recipes=%s",
        name,
        tostring(pack_err),
        tostring(objects_err),
        tostring(recipes_err)
      )
    )
  else
    local pok, perrs = schema_validator.validate_pack(pack)
    local ook, oerrs = schema_validator.validate_objects(objects)
    local rok, rerrs = schema_validator.validate_recipes(recipes, objects)
    if not (pok and ook and rok) then
      fail(
        string.format(
          "[FAIL] %s — starter pack failed validation: pack=%s objects=%s recipes=%s",
          name,
          tostring(perrs and table.concat(perrs, "; ") or nil),
          tostring(oerrs and table.concat(oerrs, "; ") or nil),
          tostring(rerrs and table.concat(rerrs, "; ") or nil)
        )
      )
    else
      local validated = {
        { pack = pack, objects = objects, recipes = recipes, sourceFile = "objects.json" },
      }
      local items, err = catalog_service.from_validated_packs(validated)
      local debug_items, debug_err = catalog_service.from_validated_packs(validated, { showDisabled = true })
      local expected_debug_count = #objects
      assert_true(
        type(items) == "table"
          and err == nil
          and #items == 0
          and type(debug_items) == "table"
          and debug_err == nil
          and #debug_items == expected_debug_count,
        name,
        string.format(
          "expected default=0 and debug=%d items, got default=%s debug=%s errs=(%s,%s)",
          expected_debug_count,
          tostring(items and #items or "nil"),
          tostring(debug_items and #debug_items or "nil"),
          tostring(err),
          tostring(debug_err)
        )
      )
    end
  end
end

-- catalog_service: disabled objects hidden by default
do
  local name = "catalog_service.from_validated_packs(disabled hidden by default)"
  local validated = {
    {
      pack = { id = "demo_pack" },
      objects = {
        {
          id = "hidden_01",
          name = "Hidden",
          type = "mesh",
          resourcePath = "props/hidden.mesh",
          category = "furniture",
          price = 0,
          tags = { "hidden" },
          disabled = true,
        },
        {
          id = "visible_01",
          name = "Visible",
          type = "mesh",
          resourcePath = "props/visible.mesh",
          category = "furniture",
          price = 0,
          tags = { "visible" },
        },
      },
      recipes = {},
      sourceFile = "objects.json",
    },
  }
  local items, err = catalog_service.from_validated_packs(validated)
  local debug_items, debug_err = catalog_service.from_validated_packs(validated, { showDisabled = true })
  local hidden_default = type(items) == "table" and #items == 1 and items[1].id == "visible_01"
  local debug_has_both = type(debug_items) == "table" and #debug_items == 2
  assert_true(
    err == nil and debug_err == nil and hidden_default and debug_has_both,
    name,
    string.format(
      "expected default visible-only and debug include-disabled; got default=%s debug=%s errs=(%s,%s)",
      tostring(items and #items or "nil"),
      tostring(debug_items and #debug_items or "nil"),
      tostring(err),
      tostring(debug_err)
    )
  )
end

-- catalog_service: category index generation
do
  local name = "catalog_service.build_category_index(generates category buckets)"
  local items = {
    { id = "a", category = "furniture" },
    { id = "b", category = "decor" },
    { id = "c", category = "furniture" },
    { id = "d", category = "lighting" },
  }
  local index, err = catalog_service.build_category_index(items)
  local ok_index = type(index) == "table"
    and err == nil
    and type(index.furniture) == "table"
    and type(index.decor) == "table"
    and type(index.lighting) == "table"
    and #index.furniture == 2
    and #index.decor == 1
    and #index.lighting == 1
    and index.furniture[1].id == "a"
    and index.furniture[2].id == "c"
  assert_true(
    ok_index,
    name,
    string.format(
      "expected buckets furniture=2 decor=1 lighting=1; got err=%s",
      tostring(err)
    )
  )
end

-- catalog_service: search by name
do
  local name = "catalog_service.search(matches by name substring)"
  local items = {
    { id = "a1", name = "Starter Chair", category = "furniture", resourcePath = "x", tags = { "seat" } },
    { id = "b1", name = "Steel Table", category = "furniture", resourcePath = "y", tags = { "surface" } },
    { id = "c1", name = "Neon Lamp", category = "lighting", resourcePath = "z", tags = { "light" } },
  }
  local matches, err = catalog_service.search(items, "chair")
  local ok_search = type(matches) == "table" and err == nil and #matches == 1 and matches[1].id == "a1"
  assert_true(
    ok_search,
    name,
    string.format("expected one match (a1) for query 'chair'; got err=%s count=%s", tostring(err), tostring(matches and #matches or "nil"))
  )
end

-- catalog_service: search by tag
do
  local name = "catalog_service.search(matches by tag substring)"
  local items = {
    { id = "a1", name = "Starter Chair", category = "furniture", resourcePath = "x", tags = { "seating", "indoor" } },
    { id = "b1", name = "Steel Table", category = "furniture", resourcePath = "y", tags = { "surface" } },
    { id = "c1", name = "Neon Lamp", category = "lighting", resourcePath = "z", tags = { "lighting", "neon" } },
  }
  local matches, err = catalog_service.search(items, "seat")
  local ok_search = type(matches) == "table" and err == nil and #matches == 1 and matches[1].id == "a1"
  assert_true(
    ok_search,
    name,
    string.format("expected one tag match (a1) for query 'seat'; got err=%s count=%s", tostring(err), tostring(matches and #matches or "nil"))
  )
end

-- catalog_service: duplicate global catalog id rejection
do
  local name = "catalog_service.validate_no_duplicate_global_ids(rejects duplicates)"
  local items = {
    { id = "obj_01", packId = "pack_a", name = "First" },
    { id = "obj_01", packId = "pack_a", name = "Duplicate" },
  }
  local ok_dup, err = catalog_service.validate_no_duplicate_global_ids(items)
  local rejected = ok_dup == false and type(err) == "string" and err:find("duplicate global catalog id", 1, true) ~= nil
  assert_true(
    rejected,
    name,
    string.format("expected duplicate rejection, got ok=%s err=%s", tostring(ok_dup), tostring(err))
  )
end

-- catalog_service: negative price rejection
do
  local name = "catalog_service.validate_non_negative_prices(rejects negative)"
  local items = {
    { id = "obj_ok", packId = "pack_a", price = 0 },
    { id = "obj_bad", packId = "pack_a", price = -1 },
  }
  local ok_price, err = catalog_service.validate_non_negative_prices(items)
  local rejected = ok_price == false and type(err) == "string" and err:find("negative price", 1, true) ~= nil
  assert_true(
    rejected,
    name,
    string.format("expected negative price rejection, got ok=%s err=%s", tostring(ok_price), tostring(err))
  )
end

-- catalog_service: invalid tags rejection
do
  local name = "catalog_service.validate_lowercase_tags(rejects invalid tags)"
  local items = {
    { id = "obj_ok", packId = "pack_a", tags = { "valid", "lowercase" } },
    { id = "obj_bad", packId = "pack_a", tags = { "InvalidTag" } },
  }
  local ok_tags, err = catalog_service.validate_lowercase_tags(items)
  local rejected = ok_tags == false and type(err) == "string" and err:find("non-lowercase tag", 1, true) ~= nil
  assert_true(
    rejected,
    name,
    string.format("expected invalid tag rejection, got ok=%s err=%s", tostring(ok_tags), tostring(err))
  )
end

-- catalog_service: deterministic cyberbuilder_catalog.json output
do
  local name = "catalog_service.export_catalog_snapshot(deterministic output)"
  local tmp_root = path_utils.join(TEST_DIR, "_tmp_catalog_snapshot")
  local items = {
    {
      id = "b_obj",
      packId = "pack_z",
      name = "Beta",
      type = "mesh",
      category = "furniture",
      tags = { "decor", "indoor" },
      price = 10,
      resourcePath = "props/beta.mesh",
      recipe = { objectId = "b_obj", seconds = 5, components = {} },
      sourceFile = "objects.json",
    },
    {
      id = "a_obj",
      packId = "pack_a",
      name = "Alpha",
      type = "mesh",
      category = "furniture",
      tags = { "decor" },
      price = 1,
      resourcePath = "props/alpha.mesh",
      recipe = { objectId = "a_obj", seconds = 1, components = {} },
      sourceFile = "objects.json",
    },
  }
  local sorted, sort_err = catalog_service.sort_items(items)
  if not sorted then
    fail(string.format("[FAIL] %s — could not sort items: %s", name, tostring(sort_err)))
  else
    local out1, err1 = catalog_service.export_catalog_snapshot(sorted, tmp_root)
    if not out1 then
      fail(string.format("[FAIL] %s — first export failed: %s", name, tostring(err1)))
    else
      local f1 = io.open(out1, "rb")
      local body1 = f1 and f1:read("*a") or nil
      if f1 then
        f1:close()
      end
      local out2, err2 = catalog_service.export_catalog_snapshot(sorted, tmp_root)
      if not out2 then
        fail(string.format("[FAIL] %s — second export failed: %s", name, tostring(err2)))
      else
        local f2 = io.open(out2, "rb")
        local body2 = f2 and f2:read("*a") or nil
        if f2 then
          f2:close()
        end
        local deterministic = type(body1) == "string" and body1 ~= "" and body1 == body2
        assert_true(deterministic, name, "expected catalog snapshot bytes to match across repeated exports")
        pcall(os.remove, out2)
      end
    end
  end
end

-- validate_pack: bad id slug
do
  local name = "schema_validator.validate_pack(invalid id slug)"
  local pack = {
    id = "BadSlug",
    name = "x",
    version = "1",
    author = "t",
    requires = {},
  }
  local pok, perrs = schema_validator.validate_pack(pack)
  assert_true(pok == false and type(perrs) == "table" and #perrs > 0, name, "expected errors table")
end

-- validate_objects: duplicate id detection (error text must call out duplicate + id)
do
  local name = "schema_validator.validate_objects(duplicate object id detection)"
  local objects = {
    {
      id = "dup",
      name = "a",
      type = "mesh",
      resourcePath = "x",
      category = "c",
      price = 0,
      tags = {},
      buildable = true,
      deletable = true,
    },
    {
      id = "dup",
      name = "b",
      type = "mesh",
      resourcePath = "y",
      category = "c",
      price = 0,
      tags = {},
      buildable = true,
      deletable = true,
    },
  }
  local ook, oerrs = schema_validator.validate_objects(objects)
  local found_dup = false
  if type(oerrs) == "table" then
    for _, m in ipairs(oerrs) do
      if type(m) == "string" and m:find("duplicate", 1, true) and m:find("dup", 1, true) then
        found_dup = true
        break
      end
    end
  end
  assert_true(ook == false and found_dup, name, "expected duplicate id error in validation messages")
end

-- validate_recipes: recipe references object id not present in objects.json
do
  local name = "schema_validator.validate_recipes(recipe missing object id)"
  local objects = {
    {
      id = "only_one",
      name = "o",
      type = "mesh",
      resourcePath = "p",
      category = "c",
      price = 0,
      tags = {},
      buildable = true,
      deletable = true,
    },
  }
  local recipes = {
    { objectId = "ghost", components = {}, seconds = 0 },
  }
  local rok, rerrs = schema_validator.validate_recipes(recipes, objects)
  local found_missing = false
  if type(rerrs) == "table" then
    for _, m in ipairs(rerrs) do
      if
        type(m) == "string"
        and m:find("unknown object id", 1, true)
        and m:find("ghost", 1, true)
        and m:find("objects.json", 1, true)
      then
        found_missing = true
        break
      end
    end
  end
  assert_true(rok == false and found_missing, name, "expected unknown objectId error for missing target")
end

-- worldbuilder_exporter: disabled objects do not contribute export lines
do
  local name = "worldbuilder_exporter.export_mesh_all(disabled objects not exported)"
  local objects = {
    {
      id = "disabled_mesh",
      name = "off",
      type = "mesh",
      resourcePath = "shapes/hidden.mesh",
      category = "x",
      price = 0,
      tags = {},
      buildable = true,
      deletable = true,
      disabled = true,
    },
    {
      id = "enabled_mesh",
      name = "on",
      type = "mesh",
      resourcePath = "shapes/visible.mesh",
      category = "x",
      price = 0,
      tags = {},
      buildable = true,
      deletable = true,
    },
  }
  local mok, _, mn = worldbuilder_exporter.export_mesh_all(objects, "tpack", repo, nil, true)
  assert_true(
    mok == true and mn == 1,
    name,
    string.format("expected exactly 1 mesh path (enabled only); got ok=%s count=%s", tostring(mok), tostring(mn))
  )
end

-- json_loader.read: malformed file must not crash (pcall + nil, err)
do
  local name = "json_loader.read(invalid JSON no crash)"
  local bad_path = path_utils.join(TEST_DIR, "_tmp_invalid_json.json")
  local fh, ferr = io.open(bad_path, "wb")
  if not fh then
    fail(string.format("[FAIL] %s — could not write temp file: %s", name, tostring(ferr)))
  else
    fh:write("{ this is not valid json")
    fh:close()
    local ok, decoded, err = pcall(json_loader.read, bad_path)
    pcall(os.remove, bad_path)
    assert_true(
      ok and decoded == nil and type(err) == "string" and err:find("invalid JSON", 1, true),
      name,
      string.format("ok=%s decoded=%s err=%s", tostring(ok), tostring(decoded), tostring(err))
    )
  end
end

-- json_loader.read: missing pack.json (path under a pack folder) must not throw
do
  local name = "json_loader.read(missing pack.json no crash)"
  local missing_pack_json = path_utils.join(TEST_DIR, "_tmp_no_manifest_pack_dir", "pack.json")
  local ok, decoded, err = pcall(json_loader.read, missing_pack_json)
  local open_err = type(err) == "string"
    and (err:find("cannot open", 1, true) or err:find("cannot", 1, true))
  assert_true(
    ok and decoded == nil and open_err,
    name,
    string.format("ok=%s decoded=%s err=%s", tostring(ok), tostring(decoded), tostring(err))
  )
end

-- worldbuilder_exporter: mesh export lines are sorted; two runs yield identical file bytes
do
  local name = "worldbuilder_exporter.export_mesh_all(deterministic sorted output)"
  local tmp_root = path_utils.join(TEST_DIR, "_tmp_deterministic_dist")
  local objects = {
    {
      id = "z",
      name = "z",
      type = "mesh",
      resourcePath = "textures/zebra.mesh",
      category = "c",
      price = 0,
      tags = {},
      buildable = true,
      deletable = true,
    },
    {
      id = "a",
      name = "a",
      type = "mesh",
      resourcePath = "textures/alpha.mesh",
      category = "c",
      price = 0,
      tags = {},
      buildable = true,
      deletable = true,
    },
    {
      id = "m",
      name = "m",
      type = "mesh",
      resourcePath = "textures/middle.mesh",
      category = "c",
      price = 0,
      tags = {},
      buildable = true,
      deletable = true,
    },
  }
  local ok1, out_path, n = worldbuilder_exporter.export_mesh_all(objects, "sortpack", tmp_root, nil, false)
  if not ok1 or not out_path then
    fail(string.format("[FAIL] %s — first export failed: %s", name, tostring(out_path)))
  else
    local f1 = io.open(out_path, "rb")
    local body1 = f1 and f1:read("*a") or nil
    if f1 then
      f1:close()
    end
    local lines = {}
    if type(body1) == "string" and body1 ~= "" then
      local b = body1:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\n$", "")
      for line in b:gmatch("[^\n]+") do
        lines[#lines + 1] = line
      end
    end
    local expected = {
      path_utils.normalize("textures/alpha.mesh"),
      path_utils.normalize("textures/middle.mesh"),
      path_utils.normalize("textures/zebra.mesh"),
    }
    local sorted_ok = #lines == #expected and n == #expected
    if sorted_ok then
      for i = 1, #expected do
        if lines[i] ~= expected[i] then
          sorted_ok = false
          break
        end
      end
    end
    assert_true(sorted_ok, name, string.format("lines not sorted as expected: %s", table.concat(lines, " | ")))

    local ok2, _, _ = worldbuilder_exporter.export_mesh_all(objects, "sortpack", tmp_root, nil, false)
    local f2 = io.open(out_path, "rb")
    local body2 = f2 and f2:read("*a") or nil
    if f2 then
      f2:close()
    end
    assert_true(ok2 and body1 == body2, name, "second export must match first byte-for-byte")
    pcall(os.remove, out_path)
  end
end

-- logger: level filter should suppress INFO when WARN configured
do
  local name = "logger.configure(level filter WARN suppresses INFO)"
  local log_path = path_utils.join(TEST_DIR, "_tmp_logger_warn.log")
  logger.configure({
    level = "WARN",
    targets = { "files" },
    mainFilePath = log_path,
    errorFilePath = path_utils.join(TEST_DIR, "_tmp_logger_warn_errors.log"),
    context = {},
  })
  logger.info("info_should_not_be_written")
  logger.warn("warn_should_be_written")
  local f = io.open(log_path, "rb")
  local body = f and f:read("*a") or ""
  if f then
    f:close()
  end
  local ok_filter = body:find("warn_should_be_written", 1, true) and not body:find("info_should_not_be_written", 1, true)
  assert_true(ok_filter, name, "expected WARN to pass and INFO to be filtered out")
  pcall(os.remove, log_path)
  pcall(os.remove, path_utils.join(TEST_DIR, "_tmp_logger_warn_errors.log"))
end

-- logger: context helper must append merged context fields
do
  local name = "logger.with_context(merged context fields)"
  local log_path = path_utils.join(TEST_DIR, "_tmp_logger_context.log")
  logger.configure({
    level = "DEBUG",
    targets = { "files" },
    mainFilePath = log_path,
    errorFilePath = path_utils.join(TEST_DIR, "_tmp_logger_context_errors.log"),
    context = { stage = "root" },
  })
  local plog = logger.with_context({ pack_id = "demo_pack", file = "objects.json" })
  plog.error("context_test_message", { code = "TEST_CTX" })
  local f = io.open(log_path, "rb")
  local body = f and f:read("*a") or ""
  if f then
    f:close()
  end
  local has_all = body:find("context_test_message", 1, true)
    and body:find("pack_id=demo_pack", 1, true)
    and body:find("file=objects.json", 1, true)
    and body:find("stage=root", 1, true)
    and body:find("code=TEST_CTX", 1, true)
  assert_true(has_all, name, "expected merged context fields in log output line")
  pcall(os.remove, log_path)
  pcall(os.remove, path_utils.join(TEST_DIR, "_tmp_logger_context_errors.log"))
end

-- construction_chip.category_filter: unsafe categories are always filtered
do
  local name = "construction_chip.category_filter.filter_objects(unsafe categories blocked)"
  local objects = {
    { id = "safe_01", category = "Furniture" },
    { id = "safe_02", category = "Decor" },
    { id = "unsafe_01", category = "NPC" },
    { id = "unsafe_02", category = "Vehicle" },
    { id = "unsafe_03", category = "Quest" },
  }
  local filtered, err = category_filter.filter_objects(
    objects,
    category_filter.ALLOWLIST_CATEGORIES,
    category_filter.DENYLIST_CATEGORIES
  )
  local ok_filtered = type(filtered) == "table"
    and err == nil
    and type(filtered.allowed) == "table"
    and type(filtered.blocked) == "table"
    and #filtered.allowed == 2
    and #filtered.blocked == 3
  local valid_ok, valid_err = category_filter.validate_unsafe_categories_filtered(
    filtered,
    category_filter.DENYLIST_CATEGORIES
  )
  assert_true(
    ok_filtered and valid_ok == true and valid_err == nil,
    name,
    string.format(
      "expected safe=2 blocked=3 and validation pass; got allowed=%s blocked=%s err=%s valid_err=%s",
      tostring(filtered and filtered.allowed and #filtered.allowed or "nil"),
      tostring(filtered and filtered.blocked and #filtered.blocked or "nil"),
      tostring(err),
      tostring(valid_err)
    )
  )
end

-- construction_chip.category_filter: validator rejects denylist category in allowed set
do
  local name = "construction_chip.category_filter.validate_unsafe_categories_filtered(rejects unsafe allowed)"
  local filtered_result = {
    allowed = {
      { id = "bad_01", category = "NPC" },
    },
    blocked = {},
  }
  local ok_safe, err = category_filter.validate_unsafe_categories_filtered(
    filtered_result,
    category_filter.DENYLIST_CATEGORIES
  )
  local rejected = ok_safe == false and type(err) == "string" and err:find("unsafe category", 1, true) ~= nil
  assert_true(
    rejected,
    name,
    string.format("expected unsafe allowed rejection, got ok=%s err=%s", tostring(ok_safe), tostring(err))
  )
end

-- construction_chip.build_authorizer: disabled objects are rejected from authorization
do
  local name = "construction_chip.build_authorizer.authorize_object(rejects disabled)"
  local entry, err = build_authorizer.authorize_object({
    id = "disabled_obj_01",
    name = "Disabled Object",
    type = "mesh",
    resourcePath = "props/disabled.mesh",
    category = "Furniture",
    tags = { "buildable", "safe" },
    disabled = true,
  }, "test_pack")
  local rejected = entry == nil and type(err) == "string" and err:find("disabled object cannot be authorized", 1, true) ~= nil
  assert_true(
    rejected,
    name,
    string.format("expected disabled rejection, got entry=%s err=%s", tostring(entry), tostring(err))
  )
end

-- construction_chip.build_authorizer: deterministic authorization ordering
do
  local name = "construction_chip.build_authorizer.sort_authorized_entries(deterministic ordering)"
  local entries = {
    { globalId = "pack_b:z1", category = "Furniture", name = "Zeta" },
    { globalId = "pack_a:a1", category = "Decor", name = "Alpha" },
    { globalId = "pack_a:b1", category = "Decor", name = "Beta" },
    { globalId = "pack_b:a1", category = "Furniture", name = "Alpha" },
    { globalId = "pack_a:a2", category = "Decor", name = "Alpha" },
  }
  local sorted, err = build_authorizer.sort_authorized_entries(entries)
  local sorted2, err2 = build_authorizer.sort_authorized_entries(entries)
  local ok_sorted = type(sorted) == "table"
    and err == nil
    and type(sorted2) == "table"
    and err2 == nil
    and #sorted == 5
    and #sorted2 == 5
    and sorted[1].globalId == "pack_a:a1"
    and sorted[2].globalId == "pack_a:a2"
    and sorted[3].globalId == "pack_a:b1"
    and sorted[4].globalId == "pack_b:a1"
    and sorted[5].globalId == "pack_b:z1"
    and sorted[1].globalId == sorted2[1].globalId
    and sorted[2].globalId == sorted2[2].globalId
    and sorted[3].globalId == sorted2[3].globalId
    and sorted[4].globalId == sorted2[4].globalId
    and sorted[5].globalId == sorted2[5].globalId
  assert_true(
    ok_sorted,
    name,
    string.format(
      "expected deterministic order by category/name/globalId; got err=%s err2=%s",
      tostring(err),
      tostring(err2)
    )
  )
end

-- construction_chip.chip_load_service: corrupted unlock save falls back safely
do
  local name = "construction_chip.chip_load_service.load_unlock_state_with_fallback(corrupted save recovery)"
  local tmp_dir = path_utils.join(TEST_DIR, "_tmp_corrupt_unlock_save")
  if package.config:sub(1, 1) == "\\" then
    os.execute('cmd /c mkdir "' .. tmp_dir:gsub("/", "\\"):gsub('"', "") .. '" 2>nul')
  else
    os.execute('mkdir "' .. tmp_dir:gsub('"', "") .. '" 2>/dev/null')
  end
  local bad_file = path_utils.join(tmp_dir, "player_unlocks.json")
  local fh, ferr = io.open(bad_file, "wb")
  if not fh then
    fail(string.format("[FAIL] %s — could not create corrupted save file: %s", name, tostring(ferr)))
  else
    fh:write("{ invalid unlock json")
    fh:close()
    local data, err = chip_load_service.load_unlock_state_with_fallback(tmp_dir)
    local ok_fallback = type(data) == "table"
      and type(err) == "string"
      and err:find("used fallback", 1, true) ~= nil
      and data.version == "0.3.0"
      and data.chipState == "installed"
      and data.activeTier == "Tier1"
      and type(data.unlockedTiers) == "table"
      and #data.unlockedTiers == 1
      and data.unlockedTiers[1] == "Tier1"
      and type(data.unlockedObjectIds) == "table"
      and #data.unlockedObjectIds == 0
      and data.updatedAt == "1970-01-01T00:00:00Z"
    assert_true(
      ok_fallback,
      name,
      string.format("expected fallback unlock state, got data=%s err=%s", tostring(data), tostring(err))
    )
    pcall(os.remove, bad_file)
    if package.config:sub(1, 1) == "\\" then
      os.execute('cmd /c rmdir "' .. tmp_dir:gsub("/", "\\"):gsub('"', "") .. '" 2>nul')
    else
      os.execute('rmdir "' .. tmp_dir:gsub('"', "") .. '" 2>/dev/null')
    end
  end
end

-- construction_chip.unlock_registry: duplicate unlock id detection
do
  local name = "construction_chip.unlock_registry.validate_no_duplicate_unlock_ids(rejects duplicates)"
  local ok_dup, err_dup = unlock_registry.validate_no_duplicate_unlock_ids({
    "unlock_tier1",
    "unlock_tier2",
    "unlock_tier1",
  })
  local rejected = ok_dup == false
    and type(err_dup) == "string"
    and err_dup:find("duplicate unlock id", 1, true) ~= nil
    and err_dup:find("unlock_tier1", 1, true) ~= nil
  assert_true(
    rejected,
    name,
    string.format("expected duplicate unlock id rejection, got ok=%s err=%s", tostring(ok_dup), tostring(err_dup))
  )
end

-- construction_chip.catalog_projection: hidden/internal excluded by default
do
  local name = "construction_chip.catalog_projection.project(excludes hidden/internal by default)"
  local entries = {
    {
      globalId = "pack:visible_01",
      packId = "pack",
      objectId = "visible_01",
      name = "Visible",
      type = "mesh",
      category = "Furniture",
      tags = { "buildable" },
      resourcePath = "props/visible.mesh",
      authorized = true,
    },
    {
      globalId = "pack:hidden_01",
      packId = "pack",
      objectId = "hidden_01",
      name = "Hidden",
      type = "mesh",
      category = "Furniture",
      tags = { "hidden" },
      resourcePath = "props/hidden.mesh",
      authorized = true,
    },
    {
      globalId = "pack:internal_01",
      packId = "pack",
      objectId = "internal_01",
      name = "Internal",
      type = "mesh",
      category = "Furniture",
      tags = { "decor" },
      resourcePath = "props/internal.mesh",
      internal = true,
      authorized = true,
    },
  }
  local projected_default, err_default = catalog_projection.project(entries)
  local projected_all, err_all = catalog_projection.project(entries, { includeHidden = true })
  local ok_visibility = type(projected_default) == "table"
    and err_default == nil
    and #projected_default == 1
    and projected_default[1].objectId == "visible_01"
    and type(projected_all) == "table"
    and err_all == nil
    and #projected_all == 3
  assert_true(
    ok_visibility,
    name,
    string.format(
      "expected default=1 visible and includeHidden=3 total; got default=%s all=%s errs=(%s,%s)",
      tostring(projected_default and #projected_default or "nil"),
      tostring(projected_all and #projected_all or "nil"),
      tostring(err_default),
      tostring(err_all)
    )
  )
end

-- construction_chip.build_authorizer: packs flagged invalid (e.g. missing dependencies) are skipped
do
  local name = "construction_chip.build_authorizer.generate_from_valid_packs(skips missing-dependency packs)"
  local validated_packs = {
    {
      isValid = true,
      pack = { id = "ok_pack" },
      objects = {
        {
          id = "ok_obj_01",
          name = "OK",
          type = "mesh",
          resourcePath = "props/ok.mesh",
          category = "Furniture",
          tags = { "buildable", "safe" },
          disabled = false,
        },
      },
    },
    {
      isValid = false,
      validationErrors = { "missing required dependency: world_builder" },
      pack = { id = "missing_dep_pack" },
      objects = {
        {
          id = "bad_obj_01",
          name = "Should Be Skipped",
          type = "mesh",
          resourcePath = "props/bad.mesh",
          category = "Furniture",
          tags = { "buildable", "safe" },
          disabled = false,
        },
      },
    },
  }
  local authorized, err = build_authorizer.generate_from_valid_packs(validated_packs)
  local ok_skip = type(authorized) == "table"
    and err == nil
    and #authorized == 1
    and authorized[1].packId == "ok_pack"
    and authorized[1].objectId == "ok_obj_01"
  assert_true(
    ok_skip,
    name,
    string.format(
      "expected only valid/dependency-satisfied pack objects, got count=%s err=%s",
      tostring(authorized and #authorized or "nil"),
      tostring(err)
    )
  )
end

-- construction_chip.player_progression: tier restriction enforcement
do
  local name = "construction_chip.player_progression.can_access_tier(enforces tier restrictions)"
  player_progression.reset()
  local can_t1, err_t1 = player_progression.can_access_tier("Tier1")
  local can_t2_before, err_t2_before = player_progression.can_access_tier("Tier2")
  local unlocked, unlock_err = player_progression.unlock_tier("Tier2")
  local activated, activate_err = player_progression.set_active_tier("Tier2")
  local can_t2_after, err_t2_after = player_progression.can_access_tier("Tier2")
  local can_dev, err_dev = player_progression.can_access_tier("Developer")
  local ok_gate = can_t1 == true
    and err_t1 == nil
    and can_t2_before == false
    and err_t2_before == nil
    and unlocked == true
    and unlock_err == nil
    and activated == true
    and activate_err == nil
    and can_t2_after == true
    and err_t2_after == nil
    and can_dev == false
    and err_dev == nil
  assert_true(
    ok_gate,
    name,
    string.format(
      "expected tier gating enforcement; got t1=%s t2_before=%s t2_after=%s dev=%s errs=(%s,%s,%s,%s)",
      tostring(can_t1),
      tostring(can_t2_before),
      tostring(can_t2_after),
      tostring(can_dev),
      tostring(err_t1),
      tostring(err_t2_before),
      tostring(err_t2_after),
      tostring(err_dev)
    )
  )
end

if failures > 0 then
  io.stderr:write(string.format("\n%d test(s) failed.\n", failures))
  os.exit(1)
end
print(string.format("\nAll tests passed (%s).", arg and arg[0] or "run_pack_registry_tests.lua"))
os.exit(0)
