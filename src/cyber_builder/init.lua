-- CyberBuilder entry: load config, discover packs, validate, export, print summary.
local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local dir = this_dir()
local path_utils = dofile(dir .. "path_utils.lua")
local json_loader = dofile(dir .. "json_loader.lua")
local logger = dofile(dir .. "logger.lua")
local pack_registry = dofile(dir .. "pack_registry.lua")
local schema_validator = dofile(dir .. "schema_validator.lua")
local worldbuilder_exporter = dofile(dir .. "worldbuilder_exporter.lua")

local construction_chip_dir = path_utils.join(dir, "construction_chip")
local build_authorizer = dofile(path_utils.join(construction_chip_dir, "build_authorizer.lua"))
local player_progression = dofile(path_utils.join(construction_chip_dir, "player_progression.lua"))
local chip_load_service = dofile(path_utils.join(construction_chip_dir, "chip_load_service.lua"))

--- Dependencies that are not other pack ids (tooling / runtime capabilities).
local VIRTUAL_PACK_DEPS = {
  world_builder = true,
}

local function pack_requires_satisfied(pack, valid_pack_ids)
  if type(pack) ~= "table" or type(pack.requires) ~= "table" then
    return true
  end
  for _, r in ipairs(pack.requires) do
    if type(r) ~= "string" or r == "" then
      return false
    end
    if VIRTUAL_PACK_DEPS[r] then
    elseif valid_pack_ids[r] then
    else
      return false
    end
  end
  return true
end

local DEFAULT_LOGGING = {
  level = "INFO",
  targets = { "console" },
  mainFileName = "cyberbuilder.log",
  errorFileName = "cyberbuilder_errors.log",
  externalEnabled = false,
}

local function repo_root()
  return path_utils.normalize(path_utils.join(this_dir(), "..", ".."))
end

local function count_disabled_objects(objects)
  if type(objects) ~= "table" then
    return 0
  end
  local n = 0
  for _, o in ipairs(objects) do
    if type(o) == "table" and o.disabled == true then
      n = n + 1
    end
  end
  return n
end

--- Objects that would contribute lines to entity or mesh exports (not disabled, non-empty path).
local function count_export_eligible_objects(objects)
  if type(objects) ~= "table" then
    return 0
  end
  local n = 0
  for _, o in ipairs(objects) do
    if type(o) == "table" and o.disabled ~= true then
      local t = o.type
      if (t == "entity" or t == "mesh") and type(o.resourcePath) == "string" then
        local rp = o.resourcePath:match("^%s*(.-)%s*$") or ""
        if rp ~= "" then
          n = n + 1
        end
      end
    end
  end
  return n
end

local function load_merged_config(config_path)
  local root = repo_root()
  local config = {
    packsDir = path_utils.join(root, "packs"),
    distDir = path_utils.join(root, "dist"),
    uiEnabled = false,
    catalogHotkey = "F8",
    ignoredPackIds = { ["broken_example_pack"] = true },
    logging = {
      level = DEFAULT_LOGGING.level,
      targets = DEFAULT_LOGGING.targets,
      mainFileName = DEFAULT_LOGGING.mainFileName,
      errorFileName = DEFAULT_LOGGING.errorFileName,
      externalEnabled = DEFAULT_LOGGING.externalEnabled,
    },
  }
  local data, err = json_loader.read(config_path)
  if not data then
    if err and err:find("cannot open", 1, true) then
      logger.info(
        string.format(
          "no config file at %q — using defaults packsDir=%q distDir=%q",
          config_path,
          config.packsDir,
          config.distDir
        )
      )
      return config, nil
    end
    return nil, err
  end
  if type(data.packsDir) == "string" and data.packsDir ~= "" then
    config.packsDir = data.packsDir
  end
  if type(data.distDir) == "string" and data.distDir ~= "" then
    config.distDir = data.distDir
  end
  if type(data.worldBuilderSpawnablesDir) == "string" and data.worldBuilderSpawnablesDir ~= "" then
    config.worldBuilderSpawnablesDir = data.worldBuilderSpawnablesDir
  end
  if type(data.uiEnabled) == "boolean" then
    config.uiEnabled = data.uiEnabled
  end
  if type(data.catalogHotkey) == "string" and data.catalogHotkey ~= "" then
    config.catalogHotkey = data.catalogHotkey
  end
  if type(data.ignoredPackIds) == "table" then
    config.ignoredPackIds = {}
    for _, id in ipairs(data.ignoredPackIds) do
      if type(id) == "string" and id ~= "" then
        config.ignoredPackIds[id] = true
      end
    end
  end
  if type(data.logging) == "table" then
    local incoming = data.logging
    if type(incoming.level) == "string" and incoming.level ~= "" then
      config.logging.level = incoming.level
    end
    if type(incoming.targets) == "table" then
      local tgt = {}
      for _, t in ipairs(incoming.targets) do
        if type(t) == "string" and t ~= "" then
          tgt[#tgt + 1] = t
        end
      end
      if #tgt > 0 then
        config.logging.targets = tgt
      end
    end
    if type(incoming.mainFileName) == "string" and incoming.mainFileName ~= "" then
      config.logging.mainFileName = incoming.mainFileName
    end
    if type(incoming.errorFileName) == "string" and incoming.errorFileName ~= "" then
      config.logging.errorFileName = incoming.errorFileName
    end
    if type(incoming.externalEnabled) == "boolean" then
      config.logging.externalEnabled = incoming.externalEnabled
    end
  end
  return config, nil
end

local function is_absolute_path(p)
  if type(p) ~= "string" or p == "" then
    return false
  end
  local n = path_utils.normalize(p:gsub("\\", "/"))
  if n:sub(1, 1) == "/" then
    return true
  end
  if n:match("^%a:/") then
    return true
  end
  if n:sub(1, 2) == "//" then
    return true
  end
  return false
end

--- True if normalized `path` equals `root` or is a strict subdirectory (byte-safe, lowercased).
local function path_is_inside_or_equal(root, path)
  local r = path_utils.normalize(root):lower()
  local p = path_utils.normalize(path):lower()
  if p == r then
    return true
  end
  local prefix = r:sub(-1) == "/" and r or (r .. "/")
  return p:sub(1, #prefix) == prefix
end

--- Resolve `distDir` and refuse paths outside the repository (default safe export to project `dist` only).
local function enforce_safe_dist_dir(repo, distDir)
  local resolved
  if is_absolute_path(distDir) then
    resolved = path_utils.normalize(distDir)
  else
    resolved = path_utils.normalize(path_utils.join(repo, distDir))
  end
  if not path_is_inside_or_equal(repo, resolved) then
    return nil,
      string.format(
        "safe export: distDir %q resolves to %q which is outside project root %q; refusing to write",
        distDir,
        resolved,
        repo
      )
  end
  return resolved, nil
end

local function contains_ent_spawner_spawnables_segment(path)
  local n = path_utils.normalize(path):gsub("\\", "/"):lower()
  return n:find("entspawner/data/spawnables", 1, true) ~= nil
end

local function ensure_parent_dir_for_copy(file_path)
  local parent = file_path:match("^(.*)[/\\][^/\\]+$")
  if not parent or parent == "" then
    return true
  end
  if package.config:sub(1, 1) == "\\" then
    os.execute('cmd /c mkdir "' .. parent:gsub("/", "\\"):gsub('"', "") .. '" 2>nul')
    return true
  end
  local lfs_ok, lfs = pcall(require, "lfs")
  if not lfs_ok or not lfs or not lfs.mkdir then
    return false
  end
  local acc = nil
  for piece in parent:gmatch("[^/\\]+") do
    acc = acc and (acc .. "/" .. piece) or piece
    pcall(lfs.mkdir, acc)
  end
  return true
end

local function copy_file_binary(src, dst)
  local inf, ierr = io.open(src, "rb")
  if not inf then
    return false, string.format("cannot read %q (%s)", src, ierr or "unknown")
  end
  local body = inf:read("*a")
  inf:close()
  ensure_parent_dir_for_copy(dst)
  local outf, oerr = io.open(dst, "wb")
  if not outf then
    return false, string.format("cannot write %q (%s)", dst, oerr or "unknown")
  end
  outf:write(body or "")
  outf:close()
  return true, nil
end

--- Copy built `.txt` exports into World Builder spawnables dir when configured and path is allowed.
local function maybe_install_spawnables(repo, config, pack_id, pid, entity_src, mesh_src)
  local raw = config.worldBuilderSpawnablesDir
  if type(raw) ~= "string" or raw == "" then
    return true, nil
  end
  local resolved
  if is_absolute_path(raw) then
    resolved = path_utils.normalize(raw)
  else
    resolved = path_utils.normalize(path_utils.join(repo, raw))
  end
  if not contains_ent_spawner_spawnables_segment(resolved) then
    return false,
      string.format(
        "install export: worldBuilderSpawnablesDir %q resolves to %q which must contain entSpawner\\data\\spawnables; refusing copy",
        raw,
        resolved
      )
  end
  local copies = {}
  if entity_src and type(entity_src) == "string" then
    copies[#copies + 1] = {
      src = entity_src,
      dst = path_utils.join(resolved, "worldbuilder", "entity", "templates", "cyberbuilder_" .. pid .. ".txt"),
    }
  end
  if mesh_src and type(mesh_src) == "string" then
    copies[#copies + 1] = {
      src = mesh_src,
      dst = path_utils.join(resolved, "worldbuilder", "mesh", "all", "cyberbuilder_" .. pid .. ".txt"),
    }
  end
  for _, c in ipairs(copies) do
    local ok, err = copy_file_binary(c.src, c.dst)
    if not ok then
      return false, err
    end
    logger.info(string.format("pack %s objects.json: install copy %q -> %q", pack_id, c.src, c.dst))
  end
  return true, nil
end

local cyber_builder = {}

function cyber_builder.version()
  return "0.1.0"
end

--- Run full pipeline. Optional `opts.configPath` overrides default config location.
-- `opts.dryRun == true` (or CLI `--dry-run`) validates and logs planned exports without writing dist files or install copies.
-- Returns `true` or `false, err`.
function cyber_builder.run(opts)
  opts = type(opts) == "table" and opts or {}
  local dry_run = opts.dryRun == true
  if dry_run then
    logger.info("dry-run: no export files or install copies will be written")
  end
  local err_log = {}
  local config = nil
  local stats = nil
  local function emit_error(msg, code, ctx)
    local line = logger.make_error_line(msg, code, ctx)
    err_log[#err_log + 1] = line
    local record_ctx = type(ctx) == "table" and ctx or {}
    if code and code ~= "" then
      record_ctx.code = code
    end
    logger.error(msg, record_ctx)
  end
  local function append_pack_errors(pack_id, file_label, errs)
    if not errs then
      return
    end
    for _, m in ipairs(errs) do
      emit_error(
        string.format("pack %s %s: %s", pack_id, file_label, m),
        "PACK_VALIDATION",
        { pack_id = pack_id, file = file_label, stage = "validate" }
      )
    end
  end

  local function flush_error_log_file()
    if dry_run or not config or not config.distDir then
      return
    end
    local log_name = (config.logging and config.logging.errorFileName) or "cyberbuilder_errors.log"
    local log_path = path_utils.join(config.distDir, log_name)
    local parent = log_path:match("^(.*)[/\\][^/\\]+$")
    if parent and parent ~= "" and package.config:sub(1, 1) == "\\" then
      os.execute('cmd /c mkdir "' .. parent:gsub("/", "\\"):gsub('"', "") .. '" 2>nul')
    elseif parent and parent ~= "" then
      local lfs_ok, lfs = pcall(require, "lfs")
      if lfs_ok and lfs then
        local acc = nil
        for piece in parent:gmatch("[^/\\]+") do
          acc = acc and (acc .. "/" .. piece) or piece
          pcall(lfs.mkdir, acc)
        end
      end
    end
    local f, ferr = io.open(log_path, "wb")
    if not f then
      logger.warn(string.format("could not write cyberbuilder_errors.log: %s", ferr or "unknown"))
      return
    end
    f:write(table.concat(err_log, "\n"))
    if #err_log > 0 then
      f:write("\n")
    end
    f:close()
    logger.info(string.format("wrote error summary %q (%d lines)", log_path, #err_log), { stage = "summary_write" })
  end

  local function write_export_summary_json()
    if dry_run or not config or not config.distDir then
      return
    end
    local out_path = path_utils.join(config.distDir, "cyberbuilder_export_summary.json")
    local parent = out_path:match("^(.*)[/\\][^/\\]+$")
    if parent and parent ~= "" and package.config:sub(1, 1) == "\\" then
      os.execute('cmd /c mkdir "' .. parent:gsub("/", "\\"):gsub('"', "") .. '" 2>nul')
    elseif parent and parent ~= "" then
      local lfs_ok, lfs = pcall(require, "lfs")
      if lfs_ok and lfs then
        local acc = nil
        for piece in parent:gmatch("[^/\\]+") do
          acc = acc and (acc .. "/" .. piece) or piece
          pcall(lfs.mkdir, acc)
        end
      end
    end
    local body = string.format(
      '{"packs_found":%d,"packs_valid":%d,"packs_invalid":%d,"objects_exported":%d,"objects_skipped":%d,"entity_lines_written":%d,"mesh_lines_written":%d,"dry_run":%s,"cyber_builder_version":"%s"}\n',
      stats and stats.packs_found or 0,
      stats and stats.packs_valid or 0,
      stats and stats.packs_invalid or 0,
      stats and stats.objects_exported or 0,
      stats and stats.objects_skipped or 0,
      stats and stats.entity_lines_written or 0,
      stats and stats.mesh_lines_written or 0,
      dry_run and "true" or "false",
      cyber_builder.version()
    )
    local f, ferr = io.open(out_path, "wb")
    if not f then
      logger.warn(string.format("could not write cyberbuilder_export_summary.json: %s", ferr or "unknown"))
      return
    end
    f:write(body)
    f:close()
    logger.info(string.format("wrote export summary %q", out_path), { stage = "summary_write" })
  end

  local config_path = opts.configPath or path_utils.join(repo_root(), "cyberbuilder.config.json")
  local cerr
  config, cerr = load_merged_config(config_path)
  if not config then
    emit_error(tostring(cerr), "CFG_LOAD", { stage = "config_load", file = config_path })
    return false, cerr
  end

  local logging_cfg = type(config.logging) == "table" and config.logging or {}
  local cli_targets = type(opts.logTargets) == "table" and opts.logTargets or nil
  logger.configure({
    level = opts.logLevel or logging_cfg.level or DEFAULT_LOGGING.level,
    targets = cli_targets or logging_cfg.targets or DEFAULT_LOGGING.targets,
    context = { stage = "bootstrap" },
    externalHandler = (logging_cfg.externalEnabled == true and opts.externalLogHandler) and opts.externalLogHandler or nil,
  })
  logger.info(
    string.format(
      "logging configured level=%s targets=%s",
      tostring(opts.logLevel or logging_cfg.level or DEFAULT_LOGGING.level),
      table.concat(cli_targets or logging_cfg.targets or DEFAULT_LOGGING.targets, ",")
    ),
    { stage = "config_load", file = config_path }
  )

  local repo = repo_root()
  local safe_dist, serr = enforce_safe_dist_dir(repo, config.distDir)
  if not safe_dist then
    emit_error(serr, "CFG_DIST_OUTSIDE_REPO", { stage = "config_validate", file = "distDir" })
    return false, serr
  end
  config.distDir = safe_dist

  build_authorizer.clear_cache()
  local saves_dir = path_utils.join(repo, "saves")
  local unlock_data, unlock_note = chip_load_service.load_unlock_state_with_fallback(saves_dir)
  if unlock_note then
    logger.info("[ConstructionChip] " .. unlock_note, { stage = "unlock_load" })
  end
  player_progression.apply_chip_unlock_data(unlock_data)

  logger.configure({
    level = opts.logLevel or logging_cfg.level or DEFAULT_LOGGING.level,
    targets = cli_targets or logging_cfg.targets or DEFAULT_LOGGING.targets,
    context = { module = "cyber_builder" },
    mainFilePath = path_utils.join(
      config.distDir,
      opts.logFileName or logging_cfg.mainFileName or DEFAULT_LOGGING.mainFileName
    ),
    errorFilePath = path_utils.join(
      config.distDir,
      logging_cfg.errorFileName or DEFAULT_LOGGING.errorFileName
    ),
    externalHandler = (logging_cfg.externalEnabled == true and opts.externalLogHandler) and opts.externalLogHandler or nil,
  })

  stats = {
    packs_found = 0,
    packs_valid = 0,
    packs_invalid = 0,
    objects_exported = 0,
    objects_skipped = 0,
    entity_lines_written = 0,
    mesh_lines_written = 0,
  }

  local chip_candidates = {}

  local packs, derr = pack_registry.discover(config.packsDir)
  if not packs then
    emit_error(tostring(derr), "PACK_DISCOVER_FAILED", { stage = "discover", file = "packsDir" })
    flush_error_log_file()
    return false, derr
  end
  local ignored_set = type(config.ignoredPackIds) == "table" and config.ignoredPackIds or {}
  local active = {}
  local n_ignored = 0
  for _, entry in ipairs(packs) do
    if ignored_set[entry.id] then
      n_ignored = n_ignored + 1
      logger.info(string.format("pack %s skipped (ignoredPackIds)", entry.id), { pack_id = entry.id, stage = "discover" })
    else
      active[#active + 1] = entry
    end
  end
  if n_ignored > 0 then
    logger.info(string.format("ignored %d pack(s) via ignoredPackIds", n_ignored))
  end
  packs = active
  stats.packs_found = #packs

  for _, entry in ipairs(packs) do
    local pack_id = entry.id
    local pack_log = logger.with_context({ pack_id = pack_id, file = "pack.json" })
    local pack_path = path_utils.join(entry.path, "pack.json")
    local objects_path = path_utils.join(entry.path, "objects.json")
    local recipes_path = path_utils.join(entry.path, "recipes.json")

    local pack, perr = json_loader.read(pack_path)
    if not pack then
      emit_error(string.format("pack %s pack.json: %s", pack_id, tostring(perr)), "PACK_READ_PACK_JSON", {
        pack_id = pack_id,
        file = "pack.json",
        stage = "read_json",
      })
      stats.packs_invalid = stats.packs_invalid + 1
    else
      pack_log.debug("pack manifest loaded", { stage = "read_json" })
      local objects, oerr = json_loader.read(objects_path)
      if not objects then
        emit_error(string.format("pack %s objects.json: %s", pack_id, tostring(oerr)), "PACK_READ_OBJECTS_JSON", {
          pack_id = pack_id,
          file = "objects.json",
          stage = "read_json",
        })
        stats.packs_invalid = stats.packs_invalid + 1
      else
        local recipes, rerr = json_loader.read(recipes_path)
        if not recipes then
          emit_error(string.format("pack %s recipes.json: %s", pack_id, tostring(rerr)), "PACK_READ_RECIPES_JSON", {
            pack_id = pack_id,
            file = "recipes.json",
            stage = "read_json",
          })
          stats.packs_invalid = stats.packs_invalid + 1
        else
          local pok, perrs = schema_validator.validate_pack(pack)
          local ook, oerrs = schema_validator.validate_objects(objects)
          local rok, rerrs = schema_validator.validate_recipes(recipes, objects)
          if not pok then
            append_pack_errors(pack_id, "pack.json", perrs)
          end
          if not ook then
            append_pack_errors(pack_id, "objects.json", oerrs)
          end
          if not rok then
            append_pack_errors(pack_id, "recipes.json", rerrs)
          end
          if not pok or not ook or not rok then
            stats.packs_invalid = stats.packs_invalid + 1
          else
            chip_candidates[#chip_candidates + 1] = {
              pack = pack,
              objects = objects,
            }
            stats.packs_valid = stats.packs_valid + 1
            stats.objects_exported = stats.objects_exported + count_export_eligible_objects(objects)
            stats.objects_skipped = stats.objects_skipped + count_disabled_objects(objects)
            local pid = type(pack.id) == "string" and pack.id or pack_id
            local eok, ev, en = worldbuilder_exporter.export_entity_templates(
              objects,
              pid,
              config.distDir,
              logger,
              dry_run,
              { pack_id = pack_id, stage = "export_entity", file = "objects.json" }
            )
            if not eok then
              emit_error(string.format("pack %s objects.json: entity export %s", pack_id, tostring(ev)), "EXPORT_ENTITY", {
                pack_id = pack_id,
                file = "objects.json",
                stage = "export_entity",
              })
            else
              stats.entity_lines_written = stats.entity_lines_written + (en or 0)
            end
            local mok, mv, mn = worldbuilder_exporter.export_mesh_all(
              objects,
              pid,
              config.distDir,
              logger,
              dry_run,
              { pack_id = pack_id, stage = "export_mesh", file = "objects.json" }
            )
            if not mok then
              emit_error(string.format("pack %s objects.json: mesh export %s", pack_id, tostring(mv)), "EXPORT_MESH", {
                pack_id = pack_id,
                file = "objects.json",
                stage = "export_mesh",
              })
            else
              stats.mesh_lines_written = stats.mesh_lines_written + (mn or 0)
            end
            if not dry_run then
              local iok, ierr = maybe_install_spawnables(
                repo,
                config,
                pack_id,
                pid,
                eok and ev or nil,
                mok and mv or nil
              )
              if not iok then
                emit_error(ierr, "INSTALL_COPY", { pack_id = pack_id, stage = "install_copy", file = "objects.json" })
                flush_error_log_file()
                return false, ierr
              end
            end
          end
        end
      end
    end
  end

  local valid_pack_ids = {}
  for _, c in ipairs(chip_candidates) do
    local pid = type(c.pack.id) == "string" and c.pack.id or ""
    if pid ~= "" then
      valid_pack_ids[pid] = true
    end
  end

  local validated_packs = {}
  for _, c in ipairs(chip_candidates) do
    local deps_ok = pack_requires_satisfied(c.pack, valid_pack_ids)
    validated_packs[#validated_packs + 1] = {
      isValid = deps_ok,
      pack = c.pack,
      objects = c.objects,
    }
    if not deps_ok then
      logger.warn(
        string.format(
          "[ConstructionChip] pack %s not authorized (unsatisfied pack.requires)",
          tostring(c.pack.id)
        ),
        { pack_id = c.pack.id, stage = "pack_requires" }
      )
    end
  end

  local authorized, auth_err = build_authorizer.generate_from_valid_packs(validated_packs)
  if not authorized then
    emit_error(tostring(auth_err), "CHIP_AUTHORIZATION", { stage = "construction_chip" })
  elseif dry_run then
    logger.info(
      string.format("[ConstructionChip] dry-run: would export %d authorization entries", #authorized),
      { stage = "construction_chip" }
    )
  else
    local _, exp_err = build_authorizer.export_authorization_file(authorized, config.distDir)
    if exp_err then
      emit_error(tostring(exp_err), "CHIP_EXPORT_AUTH", { stage = "construction_chip" })
    end
    local all_chip_objects = {}
    for _, vp in ipairs(validated_packs) do
      if type(vp.objects) == "table" then
        for _, o in ipairs(vp.objects) do
          all_chip_objects[#all_chip_objects + 1] = o
        end
      end
    end
    local _, blocked_err =
      build_authorizer.export_blocked_objects_report(all_chip_objects, authorized, config.distDir)
    if blocked_err then
      emit_error(tostring(blocked_err), "CHIP_EXPORT_BLOCKED", { stage = "construction_chip" })
    end
    local _, sum_err = player_progression.export_unlock_summary(config.distDir)
    if sum_err then
      emit_error(tostring(sum_err), "CHIP_EXPORT_UNLOCK_SUMMARY", { stage = "construction_chip" })
    end
    logger.info(
      string.format("[ConstructionChip] wrote gameplay authorization (%d entries)", #authorized),
      { stage = "construction_chip" }
    )
  end

  logger.info(
    string.format(
      "validation summary: packs_found=%d packs_valid=%d packs_invalid=%d objects_exported=%d objects_skipped=%d (entity_lines=%d mesh_lines=%d dry_run=%s)",
      stats.packs_found,
      stats.packs_valid,
      stats.packs_invalid,
      stats.objects_exported,
      stats.objects_skipped,
      stats.entity_lines_written,
      stats.mesh_lines_written,
      dry_run and "1" or "0"
    )
  )
  stats.dry_run = dry_run
  flush_error_log_file()
  write_export_summary_json()
  return true, stats
end

if arg and arg[0] and type(arg[0]) == "string" and arg[0]:lower():match("init%.lua$") then
  local cli = {}
  for i = 1, #arg do
    if arg[i] == "--dry-run" then
      cli.dryRun = true
    elseif arg[i]:match("^%-%-log%-level=") then
      cli.logLevel = arg[i]:gsub("^%-%-log%-level=", "")
    elseif arg[i]:match("^%-%-log%-targets=") then
      local raw = arg[i]:gsub("^%-%-log%-targets=", "")
      cli.logTargets = {}
      for token in raw:gmatch("[^,]+") do
        cli.logTargets[#cli.logTargets + 1] = token
      end
    elseif arg[i]:match("^%-%-log%-file=") then
      cli.logFileName = arg[i]:gsub("^%-%-log%-file=", "")
    end
  end
  local ok, res = cyber_builder.run(cli)
  if not ok then
    os.exit(1)
  end
  os.exit(0)
end

return cyber_builder
