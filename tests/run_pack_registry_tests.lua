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
local logger = dofile(path_utils.join(cyber_dir, "logger.lua"))

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

if failures > 0 then
  io.stderr:write(string.format("\n%d test(s) failed.\n", failures))
  os.exit(1)
end
print(string.format("\nAll tests passed (%s).", arg and arg[0] or "run_pack_registry_tests.lua"))
os.exit(0)
