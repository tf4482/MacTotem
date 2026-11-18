-- MacTotem: keeps a shaman macro that casts the totems of the active totem bar page

local _, ns = ...

-- name of the managed macro
local MACRO = "MacTotem"
-- question mark icon, so #showtooltip shows the next totem
local ICON = 134400
-- totem buttons per totem bar page
local PER_PAGE = 4
-- totem bar pages (Call of the Elements, Ancestors, Spirits)
local PAGES = 3
-- action slot offset of the totem bar when the client does not report it
local DEFAULT_BASE = 132
-- macro constants of newer clients
local MACRO_CONSTS = Constants and Constants.MacroConsts or {}
-- general (account) macro limit
local MAX_ACCOUNT = MAX_ACCOUNT_MACROS or MACRO_CONSTS.MAX_ACCOUNT_MACROS or 120

-- names of the totem sets, one per totem bar page
local SETS = { "Call of the Elements", "Call of the Ancestors", "Call of the Spirits" }

-- totem elements with their totem slot, in default cast order
local ELEMENTS = {
  { "earth", "Earth", EARTH_TOTEM_SLOT or 2 },
  { "fire", "Fire", FIRE_TOTEM_SLOT or 1 },
  { "water", "Water", WATER_TOTEM_SLOT or 3 },
  { "air", "Air", AIR_TOTEM_SLOT or 4 },
}
-- element key to totem slot
local SLOTS = {}
-- element choices for the order dropdowns
local ELEMENT_CHOICES = {}
-- element keys for the order command
local ELEMENT_KEYS = {}
for index, element in ipairs(ELEMENTS) do
  SLOTS[element[1]] = element[3]
  ELEMENT_CHOICES[index] = { element[1], element[2] }
  ELEMENT_KEYS[index] = element[1]
end

-- full macro list already reported once
local warned = false

-- whether the player is a shaman
local function IsShaman()
  return select(2, UnitClass("player")) == "SHAMAN"
end

-- whether the macro should be managed now
local function Active()
  return ns.db ~= nil and ns.db.enabled and IsShaman()
end

-- action slot offset of the totem bar
local function ActionBase()
  local index = C_ActionBar and C_ActionBar.GetMultiCastBarIndex and C_ActionBar.GetMultiCastBarIndex()
  if not index or index < 1 then
    return DEFAULT_BASE
  end
  return (index - 1) * NUM_ACTIONBAR_BUTTONS
end

-- active totem bar page, as chosen on the Blizzard totem bar
local function Page()
  return MultiCastActionBarFrame and MultiCastActionBarFrame.currentPage or 1
end

-- saved key of a cast position within a totem set
local function Key(page, position)
  return "order" .. page .. "_" .. position
end

-- totem names on the active page, in the element order of its totem set
local function Totems()
  local names = {}
  local page = Page()
  local first = ActionBase() + (page - 1) * PER_PAGE
  for index = 1, PER_PAGE do
    local kind, id = GetActionInfo(first + SLOTS[ns.db[Key(page, index)]])
    local name = kind == "spell" and C_Spell.GetSpellName(id)
    if name then
      names[#names + 1] = name
    end
  end
  return names
end

-- element order of a totem set as text
local function Order(page)
  local order = {}
  for index = 1, PER_PAGE do
    order[index] = ns.db[Key(page, index)]
  end
  return table.concat(order, ", ")
end

-- reset condition of the cast sequence
local function Reset()
  return ns.db.reset > 0 and "combat/" .. ns.db.reset or "combat"
end

-- macro text for the given totems; tooltip only when the page is empty
local function Body(names)
  if #names == 0 then
    return "#showtooltip"
  end
  return "#showtooltip\n/castsequence reset=" .. Reset() .. " " .. table.concat(names, ", ")
end

-- rewrite the general macro, create it if missing; never deletes; only called out of combat
local function Apply()
  if not Active() then
    return
  end
  local body = Body(Totems())
  local account = GetNumMacros()
  for index = 1, account do
    if GetMacroInfo(index) == MACRO then
      if GetMacroBody(index) ~= body then
        EditMacro(index, MACRO, nil, body)
      end
      return
    end
  end
  if account >= MAX_ACCOUNT then
    if not warned then
      ns.Error("no free general macro slot for " .. MACRO)
      warned = true
    end
    return
  end
  CreateMacro(MACRO, ICON, body, false)
end

-- update now, or right after combat
local function Refresh()
  ns.AfterCombat(Apply)
end

-- swap the element out of the other position of the set, so every element stays once
local function KeepUnique(page, position, element)
  local used = {}
  for index = 1, PER_PAGE do
    used[ns.db[Key(page, index)]] = true
  end
  for index = 1, PER_PAGE do
    if index ~= position and ns.db[Key(page, index)] == element then
      for _, key in ipairs(ELEMENT_KEYS) do
        if not used[key] then
          ns.Set(Key(page, index), key)
          return
        end
      end
    end
  end
end

-- current state and the totems of the active page
local function Status()
  local hint = ""
  if not IsShaman() then
    hint = ns.Color("warning", " (shamans only)")
  elseif not ns.db.enabled then
    hint = ns.Color("muted", " - turn on with ") .. ns.Color("command", ns.slash .. " on")
  elseif InCombatLockdown() then
    hint = ns.Color("warning", " (updates after combat)")
  end
  ns.Print("macro " .. ns.Color("value", MACRO) .. " " .. ns.OnOff(ns.db.enabled) .. hint)
  ns.Detail("reset " .. ns.Color("value", Reset()))
  for page, set in ipairs(SETS) do
    ns.Detail(set .. " (" .. page .. "): " .. ns.Color("value", Order(page)))
  end
  if IsShaman() then
    local names = Totems()
    ns.Detail("active: " .. ns.Color("value", SETS[Page()] or Page()) .. ": "
      .. (#names > 0 and ns.Color("value", table.concat(names, ", ")) or ns.Color("muted", "no totems")))
  end
end

-- switch the macro management and report the new state
local function Switch(enabled)
  ns.Set("enabled", enabled)
  Status()
end

-- follow page changes on the Blizzard totem bar
if ChangeMultiCastActionPage then
  hooksecurefunc("ChangeMultiCastActionPage", Refresh)
end

-- event handlers by event name
local events = {}

-- world ready: action slots are known
function events.PLAYER_ENTERING_WORLD()
  Refresh()
end

-- totem bar rebuilt, e.g. after learning totems
function events.UPDATE_MULTI_CAST_ACTIONBAR()
  Refresh()
end

-- totem assigned to or removed from a totem bar slot
function events.ACTIONBAR_SLOT_CHANGED(slot)
  local base = ActionBase()
  if not slot or slot == 0 or (slot > base and slot <= base + PAGES * PER_PAGE) then
    Refresh()
  end
end

-- one frame dispatching all events above
local frame = CreateFrame("Frame")
for event in pairs(events) do
  frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, ...)
  events[event](...)
end)

-- saved defaults: off, element order of ELEMENTS in every totem set
local defaults = { enabled = false, reset = 0 }
for page = 1, PAGES do
  for index, key in ipairs(ELEMENT_KEYS) do
    defaults[Key(page, index)] = key
  end
end

-- saved state; settings page and first update once loaded
ns.Store("MacTotemDB", defaults, function()
  ns.Settings()
  ns.Checkbox("enabled", "Manage macro", "Keep the MacTotem macro in sync with the active totem bar page", Refresh)
  ns.Slider("reset", "Reset after seconds", 0, 60, 1,
    "Seconds without a cast until the sequence restarts; 0 restarts only after combat", Refresh)
  -- four order dropdowns per totem set
  for page, set in ipairs(SETS) do
    for index = 1, PER_PAGE do
      ns.Dropdown(Key(page, index), set .. ": Totem " .. index, ELEMENT_CHOICES,
        "Element cast at position " .. index .. " for " .. set .. "; picking a used element swaps it",
        function(value)
          KeepUnique(page, index, value)
          Refresh()
        end)
    end
  end
  Refresh()
end)

-- chat commands
ns.Command({ name = "on", help = "manage the macro", run = function() Switch(true) end })
ns.Command({ name = "off", help = "stop managing the macro", run = function() Switch(false) end })
ns.Command({
  name = "reset",
  help = "seconds until the sequence restarts, 0 = only after combat",
  args = { { name = "seconds", type = "number", min = 0, max = 60 } },
  run = function(args)
    ns.Set("reset", math.floor(args.seconds))
    Status()
  end,
})
ns.Command({
  name = "order",
  help = "cast order of a totem set (1-3), each element once",
  args = {
    { name = "set", type = "number", min = 1, max = PAGES },
    { name = "first", choices = ELEMENT_KEYS },
    { name = "second", choices = ELEMENT_KEYS },
    { name = "third", choices = ELEMENT_KEYS },
    { name = "fourth", choices = ELEMENT_KEYS },
  },
  run = function(args)
    local order = { args.first, args.second, args.third, args.fourth }
    local seen = {}
    for _, element in ipairs(order) do
      if seen[element] then
        return ns.Error("name every element once")
      end
      seen[element] = true
    end
    -- set positions in turn; swaps only touch later positions
    local page = math.floor(args.set)
    for index, element in ipairs(order) do
      ns.Set(Key(page, index), element)
    end
    Status()
  end,
})
ns.Command({ name = "config", help = "open the settings page", run = ns.OpenSettings })
ns.Slash({ "/mt", "/mactotem" }, Status)
