--[[ StaticImage - Display.lua
     Builds and updates the on-screen image frames from StaticImageDB.images.
     Frames are a reusable pool: pool slot i always displays image i, so after
     an insert/delete we just re-apply every slot. Rotation/mirror uses the
     8-argument SetTexCoord (there is no Texture:SetRotation in 1.12). ]]

StaticImage_Frames = {}        -- pool: [i] = { frame = <Frame>, tex = <Texture> }
StaticImage_FrameCount = 0     -- highest pool slot created so far

-- Rotate (degrees) and/or mirror a texture by mapping its four corners.
function StaticImage_ApplyTexCoord(tex, deg, mirrorH, mirrorV)
  local a = deg * math.pi / 180
  local c = math.cos(a)
  local s = math.sin(a)
  local hx = 0.5
  local hy = 0.5
  if mirrorH then hx = -hx end
  if mirrorV then hy = -hy end
  -- corner offsets from texture centre (0.5,0.5), rotated, shifted back into [0,1]
  local ULx = 0.5 + (-hx) * c - (-hy) * s
  local ULy = 0.5 + (-hx) * s + (-hy) * c
  local LLx = 0.5 + (-hx) * c - ( hy) * s
  local LLy = 0.5 + (-hx) * s + ( hy) * c
  local URx = 0.5 + ( hx) * c - (-hy) * s
  local URy = 0.5 + ( hx) * s + (-hy) * c
  local LRx = 0.5 + ( hx) * c - ( hy) * s
  local LRy = 0.5 + ( hx) * s + ( hy) * c
  tex:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
end

local function CreateDisplayFrame(i)
  local frame = CreateFrame("Frame", "StaticImageDisplay"..i, UIParent)
  frame:SetWidth(128)
  frame:SetHeight(128)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame.index = i

  local tex = frame:CreateTexture("StaticImageDisplay"..i.."Tex", "ARTWORK")
  tex:SetAllPoints(frame)

  frame:SetScript("OnDragStart", function()
    if not StaticImageDB.locked then
      this:StartMoving()
    end
  end)
  frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    StaticImage_CapturePosition(this.index)
  end)

  StaticImage_Frames[i] = { frame = frame, tex = tex }
  if i > StaticImage_FrameCount then StaticImage_FrameCount = i end
  return StaticImage_Frames[i]
end

-- Apply the global lock state to one frame (locked = mouse off = click-through).
function StaticImage_ApplyLock(i)
  local rec = StaticImage_Frames[i]
  if rec == nil then return end
  local frame = rec.frame
  if StaticImageDB.locked then
    frame:EnableMouse(false)
    frame:SetMovable(false)
  else
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
  end
end

function StaticImage_ApplyLockAll()
  if StaticImageDB == nil then return end
  local n = table.getn(StaticImageDB.images)
  local i = 1
  while i <= n do
    StaticImage_ApplyLock(i)
    i = i + 1
  end
end

-- Push image[i]'s config onto its display frame.
function StaticImage_ApplyImage(i)
  if StaticImageDB == nil then return end
  local img = StaticImageDB.images[i]
  if img == nil then return end
  local rec = StaticImage_Frames[i]
  if rec == nil then rec = CreateDisplayFrame(i) end
  local frame = rec.frame
  local tex = rec.tex

  frame:SetWidth(img.width)
  frame:SetHeight(img.height)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", img.x, img.y)
  frame:SetFrameStrata(img.strata)
  frame:SetAlpha(img.alpha)

  tex:SetTexture(img.texture)
  tex:SetVertexColor(img.color.r, img.color.g, img.color.b)
  StaticImage_ApplyTexCoord(tex, img.rotation, img.mirrorH, img.mirrorV)

  StaticImage_ApplyLock(i)

  if img.shown then frame:Show() else frame:Hide() end
end

-- After a drag, store the frame's centre-relative offset and re-anchor to CENTER
-- so the data model stays uniform.
function StaticImage_CapturePosition(i)
  local rec = StaticImage_Frames[i]
  if rec == nil then return end
  local frame = rec.frame
  local cx, cy = frame:GetCenter()
  local px, py = UIParent:GetCenter()
  if cx == nil or px == nil then return end
  local x = cx - px
  local y = cy - py
  StaticImageDB.images[i].x = x
  StaticImageDB.images[i].y = y
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
  if StaticImageConfig_OnPositionChanged then
    StaticImageConfig_OnPositionChanged(i)
  end
end

-- Reconcile all frames with the current image list (used on login and after
-- inserts/deletes shift indices).
function StaticImage_RebuildAll()
  if StaticImageDB == nil then return end
  local n = table.getn(StaticImageDB.images)
  local i = 1
  while i <= n do
    StaticImage_ApplyImage(i)
    i = i + 1
  end
  -- hide pooled frames beyond the current count
  i = n + 1
  while i <= StaticImage_FrameCount do
    if StaticImage_Frames[i] then
      StaticImage_Frames[i].frame:Hide()
    end
    i = i + 1
  end
end
