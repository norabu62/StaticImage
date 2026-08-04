--[[ StaticImage - Config.lua
     WeakAuras-style configuration window.
       Left  : scrollable vertical list of image instances (+ New/Duplicate/Delete)
       Right : per-image settings panel for the selected instance
     The window shell is in Config.xml; controls are created here in OnLoad.
     Lua 5.0 / vanilla 1.12: handlers read the globals 'this'/'arg1'. ]]

local ROWS = 12
local ROW_HEIGHT = 20
local LIST_TOP = -48       -- y of the first list row (from frame TOPLEFT)
local PANEL_X = 206        -- left x of the right-hand settings panel

local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH" }

-- shared state (upvalues for every handler defined below)
local configLoading = false
local initialized = false
local selectedIndex = 1
local listOffset = 0
local rowButtons = {}

-- control references (populated in OnLoad)
local nameBox, textureBox, xBox, yBox, wBox, hBox
local alphaSlider, rotationSlider
local colorSwatch, mirrorHCheck, mirrorVCheck, strataButton, shownCheck, lockCheck

-- ---------------------------------------------------------------- helpers ----

local function SelectedImage()
  if StaticImageDB == nil or StaticImageDB.images == nil then return nil end
  return StaticImageDB.images[selectedIndex]
end

function StaticImage_Round(v)
  if v >= 0 then return math.floor(v + 0.5) end
  return math.ceil(v - 0.5)
end

local function MakeLabel(parent, text, x, y)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  fs:SetText(text)
  return fs
end

local function MakeEditBox(name, parent, width, x, y)
  local e = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
  e:SetWidth(width)
  e:SetHeight(18)
  e:SetAutoFocus(false)
  e:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  e:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  e:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  return e
end

local function MakeSlider(name, parent, label, minV, maxV, step, width, x, y)
  local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
  s:SetWidth(width)
  s:SetHeight(16)
  s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  getglobal(name.."Text"):SetText(label)
  getglobal(name.."Low"):SetText(tostring(minV))
  getglobal(name.."High"):SetText(tostring(maxV))
  return s
end

local function MakeCheck(name, parent, label, x, y)
  local c = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
  c:SetWidth(22)
  c:SetHeight(22)
  c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  fs:SetPoint("LEFT", c, "RIGHT", 2, 0)
  fs:SetText(label)
  return c
end

local function CommitNumber(field, value, minV, maxV, isInt)
  local v = tonumber(value)
  if v == nil then return end   -- partial input like "" or "-"; ignore
  if minV ~= nil and v < minV then v = minV end
  if maxV ~= nil and v > maxV then v = maxV end
  if isInt then v = StaticImage_Round(v) end
  local img = SelectedImage()
  if img == nil then return end
  img[field] = v
  StaticImage_ApplyImage(selectedIndex)
end

local function DeepCopyImage(src)
  return {
    name = src.name, texture = src.texture,
    x = src.x, y = src.y, width = src.width, height = src.height,
    alpha = src.alpha,
    color = { r = src.color.r, g = src.color.g, b = src.color.b },
    rotation = src.rotation, mirrorH = src.mirrorH, mirrorV = src.mirrorV,
    strata = src.strata, shown = src.shown,
  }
end

-- --------------------------------------------------------- color picker ------

local function OpenColorPicker()
  local img = SelectedImage()
  if img == nil then return end
  local prevR, prevG, prevB, prevA = img.color.r, img.color.g, img.color.b, img.alpha

  ColorPickerFrame.hasOpacity = true
  ColorPickerFrame.opacity = 1 - prevA                 -- vanilla opacity is inverted
  ColorPickerFrame.previousValues = { prevR, prevG, prevB, prevA }

  ColorPickerFrame.func = function()
    local sel = SelectedImage()
    if sel == nil then return end
    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
    sel.color.r = nr; sel.color.g = ng; sel.color.b = nb
    StaticImage_ApplyImage(selectedIndex)
    if colorSwatch then colorSwatch.tex:SetVertexColor(nr, ng, nb) end
  end

  ColorPickerFrame.opacityFunc = function()
    local sel = SelectedImage()
    if sel == nil then return end
    local na = 1 - OpacitySliderFrame:GetValue()       -- invert back to alpha
    sel.alpha = na
    StaticImage_ApplyImage(selectedIndex)
    configLoading = true
    if alphaSlider then alphaSlider:SetValue(na) end
    configLoading = false
  end

  ColorPickerFrame.cancelFunc = function()
    local sel = SelectedImage()
    if sel == nil then return end
    sel.color.r = prevR; sel.color.g = prevG; sel.color.b = prevB
    sel.alpha = prevA
    StaticImage_ApplyImage(selectedIndex)
    StaticImageConfig_Refresh()
  end

  ColorPickerFrame:SetColorRGB(prevR, prevG, prevB)
  ShowUIPanel(ColorPickerFrame)
end

-- --------------------------------------------------- list / panel refresh ----

function StaticImageConfig_UpdateList()
  if StaticImageDB == nil then return end
  local n = table.getn(StaticImageDB.images)
  local maxOffset = n - ROWS
  if maxOffset < 0 then maxOffset = 0 end
  if listOffset > maxOffset then listOffset = maxOffset end
  if listOffset < 0 then listOffset = 0 end
  local r = 1
  while r <= ROWS do
    local btn = rowButtons[r]
    local dataIndex = listOffset + r
    if dataIndex <= n then
      btn.dataIndex = dataIndex
      btn.label:SetText(StaticImageDB.images[dataIndex].name or ("Image "..dataIndex))
      if dataIndex == selectedIndex then btn.selTex:Show() else btn.selTex:Hide() end
      btn:Show()
    else
      btn.dataIndex = nil
      btn:Hide()
    end
    r = r + 1
  end
end

function StaticImageConfig_LoadPanel()
  local img = SelectedImage()
  configLoading = true
  if img == nil then
    nameBox:SetText("")
    textureBox:SetText("")
    xBox:SetText(""); yBox:SetText(""); wBox:SetText(""); hBox:SetText("")
    alphaSlider:SetValue(1)
    rotationSlider:SetValue(0)
    mirrorHCheck:SetChecked(nil)
    mirrorVCheck:SetChecked(nil)
    shownCheck:SetChecked(nil)
    strataButton:SetText("Strata: -")
    colorSwatch.tex:SetVertexColor(1, 1, 1)
  else
    nameBox:SetText(img.name)
    textureBox:SetText(img.texture)
    xBox:SetText(tostring(StaticImage_Round(img.x)))
    yBox:SetText(tostring(StaticImage_Round(img.y)))
    wBox:SetText(tostring(img.width))
    hBox:SetText(tostring(img.height))
    alphaSlider:SetValue(img.alpha)
    rotationSlider:SetValue(img.rotation)
    mirrorHCheck:SetChecked(img.mirrorH)
    mirrorVCheck:SetChecked(img.mirrorV)
    shownCheck:SetChecked(img.shown)
    strataButton:SetText("Strata: "..img.strata)
    colorSwatch.tex:SetVertexColor(img.color.r, img.color.g, img.color.b)
  end
  configLoading = false
end

function StaticImageConfig_SyncLock()
  if lockCheck == nil or StaticImageDB == nil then return end
  configLoading = true
  lockCheck:SetChecked(StaticImageDB.locked)
  configLoading = false
end

function StaticImageConfig_Refresh()
  if StaticImageDB == nil then return end
  if not initialized then
    initialized = true
    if StaticImageDB.selected then selectedIndex = StaticImageDB.selected end
  end
  local n = table.getn(StaticImageDB.images)
  if selectedIndex > n then selectedIndex = n end
  if selectedIndex < 1 then selectedIndex = 1 end
  StaticImageDB.selected = selectedIndex
  StaticImageConfig_UpdateList()
  StaticImageConfig_LoadPanel()
  StaticImageConfig_SyncLock()
end

-- Called from Display.lua after an on-screen drag moves the selected image.
function StaticImageConfig_OnPositionChanged(i)
  if i ~= selectedIndex then return end
  if xBox == nil then return end
  local img = SelectedImage()
  if img == nil then return end
  configLoading = true
  xBox:SetText(tostring(StaticImage_Round(img.x)))
  yBox:SetText(tostring(StaticImage_Round(img.y)))
  configLoading = false
end

-- ------------------------------------------------------ new / dup / delete ---

function StaticImageConfig_New()
  if StaticImageDB == nil then return end
  local img = StaticImage_NewImageDefaults("Image "..(table.getn(StaticImageDB.images) + 1))
  table.insert(StaticImageDB.images, img)
  selectedIndex = table.getn(StaticImageDB.images)
  local maxOffset = table.getn(StaticImageDB.images) - ROWS
  if maxOffset < 0 then maxOffset = 0 end
  listOffset = maxOffset
  StaticImage_ApplyImage(selectedIndex)
  StaticImageConfig_Refresh()
end

function StaticImageConfig_Duplicate()
  local src = SelectedImage()
  if src == nil then return end
  local copy = DeepCopyImage(src)
  copy.name = src.name.." copy"
  table.insert(StaticImageDB.images, selectedIndex + 1, copy)
  selectedIndex = selectedIndex + 1
  StaticImage_RebuildAll()
  StaticImageConfig_Refresh()
end

function StaticImageConfig_Delete()
  if StaticImageDB == nil then return end
  if table.getn(StaticImageDB.images) == 0 then return end
  table.remove(StaticImageDB.images, selectedIndex)
  StaticImage_RebuildAll()
  StaticImageConfig_Refresh()
end

function StaticImageConfig_Toggle()
  if StaticImageConfigFrame:IsShown() then
    StaticImageConfigFrame:Hide()
  else
    StaticImageConfigFrame:Show()   -- OnShow calls Refresh
  end
end

-- ---------------------------------------------------------------- OnLoad -----

function StaticImageConfig_OnLoad()
  local frame = StaticImageConfigFrame

  -- vertical separator between list and panel
  local sep = frame:CreateTexture(nil, "ARTWORK")
  sep:SetWidth(2); sep:SetHeight(300)
  sep:SetPoint("TOPLEFT", frame, "TOPLEFT", 192, -44)
  sep:SetTexture(0.5, 0.5, 0.5, 0.5)

  -- ---- left: instance list rows ----
  local r = 1
  while r <= ROWS do
    local btn = CreateFrame("Button", "StaticImageConfigRow"..r, frame)
    btn:SetWidth(160)
    btn:SetHeight(ROW_HEIGHT)
    btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, LIST_TOP - (r - 1) * ROW_HEIGHT)

    local selTex = btn:CreateTexture(nil, "BACKGROUND")
    selTex:SetAllPoints(btn)
    selTex:SetTexture(0.3, 0.5, 0.9, 0.5)
    selTex:Hide()
    btn.selTex = selTex

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(btn)
    hl:SetTexture(1, 1, 1, 0.15)

    local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", btn, "LEFT", 4, 0)
    fs:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    fs:SetJustifyH("LEFT")
    btn:SetFontString(fs)
    btn.label = fs

    btn:EnableMouseWheel(true)
    btn:SetScript("OnMouseWheel", function()
      listOffset = listOffset - arg1
      StaticImageConfig_UpdateList()
    end)
    btn:SetScript("OnClick", function()
      if this.dataIndex == nil then return end
      selectedIndex = this.dataIndex
      StaticImageDB.selected = selectedIndex
      StaticImageConfig_Refresh()
    end)

    rowButtons[r] = btn
    r = r + 1
  end

  -- ---- left: New / Duplicate / Delete / Lock ----
  local listBottom = LIST_TOP - ROWS * ROW_HEIGHT - 8

  local newBtn = CreateFrame("Button", "StaticImageConfigNewBtn", frame, "UIPanelButtonTemplate")
  newBtn:SetWidth(78); newBtn:SetHeight(22)
  newBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, listBottom)
  newBtn:SetText("New")
  newBtn:SetScript("OnClick", function() StaticImageConfig_New() end)

  local copyBtn = CreateFrame("Button", "StaticImageConfigCopyBtn", frame, "UIPanelButtonTemplate")
  copyBtn:SetWidth(78); copyBtn:SetHeight(22)
  copyBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 98, listBottom)
  copyBtn:SetText("Duplicate")
  copyBtn:SetScript("OnClick", function() StaticImageConfig_Duplicate() end)

  local delBtn = CreateFrame("Button", "StaticImageConfigDelBtn", frame, "UIPanelButtonTemplate")
  delBtn:SetWidth(160); delBtn:SetHeight(22)
  delBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, listBottom - 26)
  delBtn:SetText("Delete")
  delBtn:SetScript("OnClick", function() StaticImageConfig_Delete() end)

  lockCheck = MakeCheck("StaticImageConfigLock", frame, "Lock (uncheck to drag)", 16, listBottom - 56)
  lockCheck:SetScript("OnClick", function()
    if configLoading then return end
    if this:GetChecked() then StaticImage_SetLocked(true) else StaticImage_SetLocked(false) end
  end)

  -- ---- right: settings panel ----
  MakeLabel(frame, "Name", PANEL_X, -46)
  nameBox = MakeEditBox("StaticImageConfigName", frame, 220, PANEL_X + 50, -44)
  nameBox:SetScript("OnTextChanged", function()
    if configLoading then return end
    local img = SelectedImage(); if img == nil then return end
    img.name = this:GetText()
    StaticImageConfig_UpdateList()
  end)

  MakeLabel(frame, "Texture path", PANEL_X, -76)
  textureBox = MakeEditBox("StaticImageConfigTexture", frame, 400, PANEL_X, -92)
  textureBox:SetScript("OnTextChanged", function()
    if configLoading then return end
    local img = SelectedImage(); if img == nil then return end
    img.texture = this:GetText()
    StaticImage_ApplyImage(selectedIndex)
  end)

  MakeLabel(frame, "X", PANEL_X, -124)
  xBox = MakeEditBox("StaticImageConfigX", frame, 60, PANEL_X + 18, -122)
  MakeLabel(frame, "Y", PANEL_X + 110, -124)
  yBox = MakeEditBox("StaticImageConfigY", frame, 60, PANEL_X + 128, -122)
  MakeLabel(frame, "W", PANEL_X, -156)
  wBox = MakeEditBox("StaticImageConfigW", frame, 60, PANEL_X + 18, -154)
  MakeLabel(frame, "H", PANEL_X + 110, -156)
  hBox = MakeEditBox("StaticImageConfigH", frame, 60, PANEL_X + 128, -154)

  xBox:SetScript("OnTextChanged", function() if configLoading then return end CommitNumber("x", this:GetText(), nil, nil, false) end)
  yBox:SetScript("OnTextChanged", function() if configLoading then return end CommitNumber("y", this:GetText(), nil, nil, false) end)
  wBox:SetScript("OnTextChanged", function() if configLoading then return end CommitNumber("width", this:GetText(), 1, 1024, true) end)
  hBox:SetScript("OnTextChanged", function() if configLoading then return end CommitNumber("height", this:GetText(), 1, 1024, true) end)

  alphaSlider = MakeSlider("StaticImageConfigAlpha", frame, "Transparency (alpha)", 0, 1, 0.01, 200, PANEL_X + 10, -200)
  alphaSlider:SetScript("OnValueChanged", function()
    if configLoading then return end
    local img = SelectedImage(); if img == nil then return end
    img.alpha = this:GetValue()
    StaticImage_ApplyImage(selectedIndex)
  end)

  rotationSlider = MakeSlider("StaticImageConfigRotation", frame, "Rotation (degrees)", 0, 360, 1, 200, PANEL_X + 10, -248)
  rotationSlider:SetScript("OnValueChanged", function()
    if configLoading then return end
    local img = SelectedImage(); if img == nil then return end
    img.rotation = this:GetValue()
    StaticImage_ApplyImage(selectedIndex)
  end)

  -- colour swatch
  MakeLabel(frame, "Color", PANEL_X, -300)
  colorSwatch = CreateFrame("Button", "StaticImageConfigColor", frame)
  colorSwatch:SetWidth(22); colorSwatch:SetHeight(22)
  colorSwatch:SetPoint("TOPLEFT", frame, "TOPLEFT", PANEL_X + 44, -298)
  local swatchTex = colorSwatch:CreateTexture(nil, "ARTWORK")
  swatchTex:SetAllPoints(colorSwatch)
  swatchTex:SetTexture(1, 1, 1)
  colorSwatch.tex = swatchTex
  colorSwatch:SetScript("OnClick", function() OpenColorPicker() end)

  mirrorHCheck = MakeCheck("StaticImageConfigMirrorH", frame, "Mirror H", PANEL_X + 90, -300)
  mirrorHCheck:SetScript("OnClick", function()
    if configLoading then return end
    local img = SelectedImage(); if img == nil then return end
    if this:GetChecked() then img.mirrorH = true else img.mirrorH = false end
    StaticImage_ApplyImage(selectedIndex)
  end)
  mirrorVCheck = MakeCheck("StaticImageConfigMirrorV", frame, "Mirror V", PANEL_X + 200, -300)
  mirrorVCheck:SetScript("OnClick", function()
    if configLoading then return end
    local img = SelectedImage(); if img == nil then return end
    if this:GetChecked() then img.mirrorV = true else img.mirrorV = false end
    StaticImage_ApplyImage(selectedIndex)
  end)

  strataButton = CreateFrame("Button", "StaticImageConfigStrata", frame, "UIPanelButtonTemplate")
  strataButton:SetWidth(150); strataButton:SetHeight(22)
  strataButton:SetPoint("TOPLEFT", frame, "TOPLEFT", PANEL_X, -338)
  strataButton:SetText("Strata: MEDIUM")
  strataButton:SetScript("OnClick", function()
    local img = SelectedImage(); if img == nil then return end
    local cur = 3
    local i = 1
    while i <= table.getn(STRATA) do
      if STRATA[i] == img.strata then cur = i end
      i = i + 1
    end
    cur = cur + 1
    if cur > table.getn(STRATA) then cur = 1 end
    img.strata = STRATA[cur]
    strataButton:SetText("Strata: "..img.strata)
    StaticImage_ApplyImage(selectedIndex)
  end)

  shownCheck = MakeCheck("StaticImageConfigShown", frame, "Show this image", PANEL_X + 170, -338)
  shownCheck:SetScript("OnClick", function()
    if configLoading then return end
    local img = SelectedImage(); if img == nil then return end
    if this:GetChecked() then img.shown = true else img.shown = false end
    StaticImage_ApplyImage(selectedIndex)
  end)

  local tip = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  tip:SetPoint("TOPLEFT", frame, "TOPLEFT", PANEL_X, -380)
  tip:SetWidth(400)
  tip:SetJustifyH("LEFT")
  tip:SetTextColor(0.7, 0.7, 0.7)
  tip:SetText("Tip: paste a texture path, e.g. Interface\\Icons\\INV_Misc_QuestionMark, "
    .. "or Interface\\AddOns\\StaticImage\\Media\\Images\\yourfile (TGA/BLP, power-of-two size, no file extension).")

  StaticImageConfig_UpdateList()
end
