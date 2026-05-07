local player_progression = {}

local TIERS = {
  "Tier1",
  "Tier2",
  "Tier3",
  "Developer",
}

local VALID_TIER = {
  Tier1 = true,
  Tier2 = true,
  Tier3 = true,
  Developer = true,
}

local TIER_ORDER = {
  Tier1 = 1,
  Tier2 = 2,
  Tier3 = 3,
  Developer = 4,
}

local state = {
  activeTier = "Tier1",
  unlockedTiers = {
    Tier1 = true,
  },
}

local function this_dir()
  local s = debug.getinfo(1, "S").source
  if s:sub(1, 1) == "@" then
    s = s:sub(2)
  end
  return (s:gsub("[^/\\]+$", ""))
end

local path_utils = dofile(this_dir() .. ".." .. package.config:sub(1, 1) .. "path_utils.lua")

local function trim(s)
  if type(s) ~= "string" then
    return ""
  end
  return (s:match("^%s*(.-)%s*$") or "")
end

local function sorted_unlocked_tiers()
  local out = {}
  for _, tier in ipairs(TIERS) do
    if state.unlockedTiers[tier] == true then
      out[#out + 1] = tier
    end
  end
  return out
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

function player_progression.get_active_tier()
  return state.activeTier
end

function player_progression.get_unlocked_tiers()
  return sorted_unlocked_tiers()
end

function player_progression.is_tier_unlocked(tier)
  local normalized = trim(tier)
  if normalized == "" then
    return false
  end
  return state.unlockedTiers[normalized] == true
end

function player_progression.unlock_tier(tier)
  local normalized = trim(tier)
  if normalized == "" then
    return false, "tier must be a non-empty string"
  end
  if not VALID_TIER[normalized] then
    return false, string.format("unknown tier %q", normalized)
  end
  state.unlockedTiers[normalized] = true
  return true, nil
end

function player_progression.set_active_tier(tier)
  local normalized = trim(tier)
  if normalized == "" then
    return false, "tier must be a non-empty string"
  end
  if not VALID_TIER[normalized] then
    return false, string.format("unknown tier %q", normalized)
  end
  if state.unlockedTiers[normalized] ~= true then
    return false, string.format("tier %q is not unlocked", normalized)
  end
  state.activeTier = normalized
  return true, nil
end

function player_progression.can_access_tier(required_tier)
  local normalized = trim(required_tier)
  if normalized == "" then
    return nil, "required_tier must be a non-empty string"
  end
  if not VALID_TIER[normalized] then
    return nil, string.format("unknown tier %q", normalized)
  end

  local active = state.activeTier
  return TIER_ORDER[active] >= TIER_ORDER[normalized], nil
end

function player_progression.is_valid_tier(tier)
  local normalized = trim(tier)
  if normalized == "" then
    return false
  end
  return VALID_TIER[normalized] == true
end

function player_progression.get_starter_unlock_profile()
  return {
    activeTier = "Tier1",
    unlockedTiers = {
      "Tier1",
    },
  }
end

function player_progression.export_unlock_summary(dist_dir)
  if type(dist_dir) ~= "string" or dist_dir == "" then
    return nil, "dist_dir must be a non-empty string"
  end

  local out_path = path_utils.join(dist_dir, "chip_unlock_summary.json")
  local summary = {
    activeTier = state.activeTier,
    unlockedTiers = sorted_unlocked_tiers(),
    unlockedTierCount = #sorted_unlocked_tiers(),
  }

  local ok, body = pcall(json_encode, summary)
  if not ok then
    return nil, "cannot encode unlock summary as JSON"
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

function player_progression.reset()
  state.activeTier = "Tier1"
  state.unlockedTiers = {
    Tier1 = true,
  }
end

--- Apply fields from `player_unlocks.json` (or fallback payload) into runtime tier state.
function player_progression.apply_chip_unlock_data(data)
  if type(data) ~= "table" then
    return false, "data must be a table"
  end
  player_progression.reset()
  if type(data.unlockedTiers) == "table" then
    for _, t in ipairs(data.unlockedTiers) do
      if type(t) == "string" and t ~= "" then
        player_progression.unlock_tier(t)
      end
    end
  end
  if type(data.activeTier) == "string" and trim(data.activeTier) ~= "" then
    local ok = player_progression.set_active_tier(data.activeTier)
    if not ok then
      state.activeTier = "Tier1"
    end
  end
  return true, nil
end

return player_progression
