-- Export to World Builder–compatible outputs.
local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local default_logger = dofile(this_dir() .. "logger.lua")
local path_utils = dofile(this_dir() .. "path_utils.lua")

local worldbuilder_exporter = {}

-- Types that have a dedicated World Builder export file in this MVP.
local EXPORT_WITH_FILE = {
  entity = true,
  mesh = true,
}

local function ensure_parent_dir(file_path)
  local parent = file_path:match("^(.*)[/\\][^/\\]+$")
  if not parent or parent == "" then
    return true, nil
  end
  if package.config:sub(1, 1) == "\\" then
    local p = parent:gsub("/", "\\"):gsub('"', "")
    os.execute('cmd /c mkdir "' .. p .. '" 2>nul')
    return true, nil
  end
  local lfs_ok, lfs = pcall(require, "lfs")
  if not lfs_ok or not lfs or not lfs.mkdir then
    return false, "cannot create output directories (install LuaFileSystem or use Windows)"
  end
  local acc = nil
  for piece in parent:gmatch("[^/\\]+") do
    acc = acc and (acc .. "/" .. piece) or piece
    pcall(lfs.mkdir, acc)
  end
  return true, nil
end

--- Drop duplicate paths while keeping first occurrence order (per export file).
local function dedupe_paths_in_order(paths)
  local seen = {}
  local out = {}
  for i = 1, #paths do
    local p = paths[i]
    if not seen[p] then
      seen[p] = true
      out[#out + 1] = p
    end
  end
  return out
end

--- Lexicographic sort of path strings (byte order) for stable, deterministic exports.
local function sort_paths_deterministic(paths)
  table.sort(paths)
  return paths
end

--- Call `visitor(obj, index)` for each object not marked `disabled: true`.
-- Skipped objects are logged with pack id and file name `objects.json`.
-- Optional `opts`: `{ warn_unsupported_types = true }` logs WARN for types not exported to any MVP file (not failure).
function worldbuilder_exporter.iter_export_objects(objects, pack_id, visitor, logger, opts, ctx)
  if type(visitor) ~= "function" then
    return
  end
  if type(pack_id) ~= "string" or pack_id == "" then
    return
  end
  local log = logger or default_logger
  if log.with_context then
    log = log.with_context(ctx or {})
  end
  opts = type(opts) == "table" and opts or {}
  if type(objects) ~= "table" then
    return
  end
  for idx, obj in ipairs(objects) do
    if type(obj) == "table" and obj.disabled == true then
      local oid = type(obj.id) == "string" and obj.id or ("#" .. tostring(idx))
      log.info(string.format("pack %s objects.json: skipped export for %q (disabled)", pack_id, oid))
    elseif type(obj) == "table" then
      if opts.warn_unsupported_types and type(obj.type) == "string" and not EXPORT_WITH_FILE[obj.type] then
        local oid = type(obj.id) == "string" and obj.id or ("#" .. tostring(idx))
        log.warn(
          string.format(
            "pack %s objects.json: skipping export for %q (unsupported type %q; no MVP export file)",
            pack_id,
            oid,
            obj.type
          )
        )
      end
      visitor(obj, idx)
    end
  end
end

--- Write one `resourcePath` per line for `type == "entity"` into
-- `<dist_root>/worldbuilder/entity/templates/cyberbuilder_<packId>.txt`.
-- Returns `true, out_path, line_count` or `false, err`.
-- If `dry_run` is true, logs the plan and does not create directories or files; still returns `line_count`.
function worldbuilder_exporter.export_entity_templates(objects, pack_id, dist_root, logger, dry_run, ctx)
  local log = logger or default_logger
  if log.with_context then
    log = log.with_context(ctx or {})
  end
  if type(pack_id) ~= "string" or pack_id == "" then
    return false, "export_entity_templates: pack_id must be a non-empty string"
  end
  if type(dist_root) ~= "string" or dist_root == "" then
    return false, "export_entity_templates: dist_root must be a non-empty string"
  end
  local fname = "cyberbuilder_" .. pack_id .. ".txt"
  local out_path = path_utils.join(dist_root, "worldbuilder", "entity", "templates", fname)
  local lines = {}
  worldbuilder_exporter.iter_export_objects(
    objects,
    pack_id,
    function(obj)
      if obj.type == "entity" and type(obj.resourcePath) == "string" then
        local rp = obj.resourcePath:match("^%s*(.-)%s*$") or ""
        if rp ~= "" then
          lines[#lines + 1] = path_utils.normalize(rp)
        end
      end
    end,
    log,
    { warn_unsupported_types = true },
    ctx
  )
  lines = sort_paths_deterministic(dedupe_paths_in_order(lines))
  local n = #lines
  if dry_run then
    log.info(
      string.format(
        "pack %s objects.json: [dry-run] would write entity export %q (%d paths)",
        pack_id,
        out_path,
        n
      )
    )
    return true, out_path, n
  end
  local okd, derr = ensure_parent_dir(out_path)
  if not okd then
    return false, derr
  end
  local f, ferr = io.open(out_path, "wb")
  if not f then
    return false, string.format("export_entity_templates: cannot open %q (%s)", out_path, ferr or "unknown")
  end
  f:write(table.concat(lines, "\n"))
  if n > 0 then
    f:write("\n")
  end
  f:close()
  log.info(string.format("pack %s objects.json: wrote entity export %q (%d paths)", pack_id, out_path, n))
  return true, out_path, n
end

--- Write one `resourcePath` per line for `type == "mesh"` into
-- `<dist_root>/worldbuilder/mesh/all/cyberbuilder_<packId>.txt`.
-- Returns `true, out_path, line_count` or `false, err`.
-- If `dry_run` is true, logs the plan and does not write files; still returns `line_count`.
function worldbuilder_exporter.export_mesh_all(objects, pack_id, dist_root, logger, dry_run, ctx)
  local log = logger or default_logger
  if log.with_context then
    log = log.with_context(ctx or {})
  end
  if type(pack_id) ~= "string" or pack_id == "" then
    return false, "export_mesh_all: pack_id must be a non-empty string"
  end
  if type(dist_root) ~= "string" or dist_root == "" then
    return false, "export_mesh_all: dist_root must be a non-empty string"
  end
  local fname = "cyberbuilder_" .. pack_id .. ".txt"
  local out_path = path_utils.join(dist_root, "worldbuilder", "mesh", "all", fname)
  local lines = {}
  worldbuilder_exporter.iter_export_objects(
    objects,
    pack_id,
    function(obj)
      if obj.type == "mesh" and type(obj.resourcePath) == "string" then
        local rp = obj.resourcePath:match("^%s*(.-)%s*$") or ""
        if rp ~= "" then
          lines[#lines + 1] = path_utils.normalize(rp)
        end
      end
    end,
    log,
    { warn_unsupported_types = true },
    ctx
  )
  lines = sort_paths_deterministic(dedupe_paths_in_order(lines))
  local n = #lines
  if dry_run then
    log.info(
      string.format(
        "pack %s objects.json: [dry-run] would write mesh export %q (%d paths)",
        pack_id,
        out_path,
        n
      )
    )
    return true, out_path, n
  end
  local okd, derr = ensure_parent_dir(out_path)
  if not okd then
    return false, derr
  end
  local f, ferr = io.open(out_path, "wb")
  if not f then
    return false, string.format("export_mesh_all: cannot open %q (%s)", out_path, ferr or "unknown")
  end
  f:write(table.concat(lines, "\n"))
  if n > 0 then
    f:write("\n")
  end
  f:close()
  log.info(string.format("pack %s objects.json: wrote mesh export %q (%d paths)", pack_id, out_path, n))
  return true, out_path, n
end

return worldbuilder_exporter
