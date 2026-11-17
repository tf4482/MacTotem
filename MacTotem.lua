-- MacTotem: keeps a shaman macro that casts the totems of the active totem bar page

local _, ns = ...

-- name of the managed character macro
local MACRO = "MacTotem"
-- question mark icon, so #showtooltip shows the next totem
local ICON = 134400
-- totem buttons per totem bar page
local PER_PAGE = 4
-- totem bar pages (Call of the Elements, Ancestors, Spirits)
local PAGES = 3
-- action slot offset of the totem bar when the client does not report it
local DEFAULT_BASE = 132
-- character macro limit, with fallbacks for older and newer clients
local MAX_MACROS = MAX_CHARACTER_MACROS
  or (Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_CHARACTER_MACROS)
  or 18

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

-- totem names on the active page, in totem bar order
local function Totems()
  local names = {}
  local first = ActionBase() + (Page() - 1) * PER_PAGE
  for index = 1, PER_PAGE do
    local slot = SHAMAN_TOTEM_PRIORITIES and SHAMAN_TOTEM_PRIORITIES[index] or index
    local kind, id = GetActionInfo(first + slot)
    local name = kind == "spell" and C_Spell.GetSpellName(id)
    if name then
      names[#names + 1] = name
    end
  end
  return names
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

-- create or update the macro; only called out of combat
local function Apply()
  if not Active() then
    return
  end
  local body = Body(Totems())
  local index = GetMacroIndexByName(MACRO)
  if index == 0 then
    local _, perCharacter = GetNumMacros()
    if perCharacter >= MAX_MACROS then
      if not warned then
        ns.Error("no free character macro slot for " .. MACRO)
        warned = true
      end
      return
    end
    CreateMacro(MACRO, ICON, body, true)
  elseif GetMacroBody(index) ~= body then
    EditMacro(index, MACRO, nil, body)
  end
end

-- update now, or right after combat
local function Refresh()
  ns.AfterCombat(Apply)
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
  if IsShaman() then
    local names = Totems()
    ns.Detail("page " .. ns.Color("value", Page()) .. ", reset " .. ns.Color("value", Reset()) .. ": "
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

-- saved state; settings page and first update once loaded
ns.Store("MacTotemDB", { enabled = false, reset = 0 }, function()
  ns.Settings()
  ns.Checkbox("enabled", "Manage macro", "Keep the MacTotem macro in sync with the active totem bar page", Refresh)
  ns.Slider("reset", "Reset after seconds", 0, 60, 1,
    "Seconds without a cast until the sequence restarts; 0 restarts only after combat", Refresh)
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
ns.Command({ name = "config", help = "open the settings page", run = ns.OpenSettings })
ns.Slash({ "/mt", "/mactotem" }, Status)
