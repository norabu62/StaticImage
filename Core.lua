--[[ StaticImage - Core.lua
     Initialization, saved-variable setup, events, slash commands, lock toggle.
     Target: WoW 1.12 (vanilla) client. Lua 5.0 -- no '#' operator, use table.getn. ]]

-- Default values for one image instance.
function StaticImage_NewImageDefaults(name)
  return {
    name = name or "Image",
    texture = "Interface\\Icons\\INV_Misc_QuestionMark",
    x = 0,
    y = 0,
    width = 128,
    height = 128,
    alpha = 1.0,
    color = { r = 1.0, g = 1.0, b = 1.0 },
    rotation = 0,
    mirrorH = false,
    mirrorV = false,
    strata = "MEDIUM",
    shown = true,
  }
end

-- Fill in any missing keys so older saves upgrade cleanly.
local function NormalizeImage(img)
  local d = StaticImage_NewImageDefaults()
  if img.name == nil then img.name = d.name end
  if img.texture == nil then img.texture = d.texture end
  if img.x == nil then img.x = d.x end
  if img.y == nil then img.y = d.y end
  if img.width == nil then img.width = d.width end
  if img.height == nil then img.height = d.height end
  if img.alpha == nil then img.alpha = d.alpha end
  if img.color == nil then img.color = { r = 1, g = 1, b = 1 } end
  if img.color.r == nil then img.color.r = 1 end
  if img.color.g == nil then img.color.g = 1 end
  if img.color.b == nil then img.color.b = 1 end
  if img.rotation == nil then img.rotation = d.rotation end
  if img.mirrorH == nil then img.mirrorH = d.mirrorH end
  if img.mirrorV == nil then img.mirrorV = d.mirrorV end
  if img.strata == nil then img.strata = d.strata end
  if img.shown == nil then img.shown = d.shown end
end

local function InitDB()
  if StaticImageDB == nil then StaticImageDB = {} end
  if StaticImageDB.locked == nil then StaticImageDB.locked = true end
  if StaticImageDB.selected == nil then StaticImageDB.selected = 1 end
  if StaticImageDB.images == nil then StaticImageDB.images = {} end
  local n = table.getn(StaticImageDB.images)
  local i = 1
  while i <= n do
    NormalizeImage(StaticImageDB.images[i])
    i = i + 1
  end
end

-- Toggle whether images are locked (click-through) or draggable.
function StaticImage_SetLocked(locked)
  if StaticImageDB == nil then return end
  StaticImageDB.locked = locked
  StaticImage_ApplyLockAll()
  if StaticImageConfig_SyncLock then StaticImageConfig_SyncLock() end
  if locked then
    DEFAULT_CHAT_FRAME:AddMessage("StaticImage: images locked.")
  else
    DEFAULT_CHAT_FRAME:AddMessage("StaticImage: images unlocked - drag to move.")
  end
end

-- Events. In 1.12, handlers read the globals 'event'/'arg1' (not parameters).
local ev = CreateFrame("Frame", "StaticImageEventFrame", UIParent)
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 == "StaticImage" then
      InitDB()
    end
  elseif event == "PLAYER_LOGIN" then
    StaticImage_RebuildAll()
  end
end)

-- Slash commands: /si (or /staticimage) toggles the config window.
SLASH_STATICIMAGE1 = "/staticimage"
SLASH_STATICIMAGE2 = "/si"
SlashCmdList["STATICIMAGE"] = function(msg)
  msg = string.lower(msg or "")
  if msg == "lock" then
    StaticImage_SetLocked(true)
  elseif msg == "unlock" then
    StaticImage_SetLocked(false)
  else
    StaticImageConfig_Toggle()
  end
end
