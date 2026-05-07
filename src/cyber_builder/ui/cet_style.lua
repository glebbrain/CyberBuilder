-- ImGui styling helpers aligned with entSpawner `modules/ui/style.lua` (subset, no game/mod deps).
local cet_style = {
  mutedColor = 0xFFA5A19B,
  extraMutedColor = 0x96A5A19B,
  highlightColor = 0xFFDCD8D1,
  regularColor = 0xFFFFFFFF,
  viewSize = 1,
}

local initialized = false

function cet_style.initialize(force)
  if not force and initialized then
    return
  end
  if type(ImGui) == "table" and type(ImGui.GetFontSize) == "function" then
    cet_style.viewSize = ImGui.GetFontSize() / 15
  else
    cet_style.viewSize = 1
  end
  initialized = true
end

function cet_style.pushGreyedOut(state)
  if not state then
    return
  end
  ImGui.PushStyleColor(ImGuiCol.Button, 0xff777777)
  ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0xff777777)
  ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0xff777777)
  ImGui.PushStyleColor(ImGuiCol.FrameBg, 0xff777777)
  ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, 0xff777777)
  ImGui.PushStyleColor(ImGuiCol.FrameBgActive, 0xff777777)
end

function cet_style.popGreyedOut(state)
  if not state then
    return
  end
  ImGui.PopStyleColor(6)
end

function cet_style.pushStyleColor(state, style, ...)
  if not state then
    return
  end
  ImGui.PushStyleColor(style, ...)
end

function cet_style.popStyleColor(state, count)
  if not state then
    return
  end
  ImGui.PopStyleColor(count or 1)
end

function cet_style.pushStyleVar(state, style, ...)
  if not state then
    return
  end
  ImGui.PushStyleVar(style, ...)
end

function cet_style.popStyleVar(state, count)
  if not state then
    return
  end
  ImGui.PopStyleVar(count or 1)
end

function cet_style.tooltip(text)
  if type(text) ~= "string" or text == "" then
    return
  end
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip(text)
  end
end

function cet_style.spacedSeparator()
  ImGui.Spacing()
  ImGui.Separator()
  ImGui.Spacing()
end

function cet_style.sectionHeaderStart(text, tip)
  ImGui.PushStyleColor(ImGuiCol.Text, cet_style.mutedColor)
  ImGui.SetWindowFontScale(0.85)
  ImGui.Text(text)
  if tip then
    cet_style.tooltip(tip)
  end
  ImGui.SetWindowFontScale(1)
  ImGui.PopStyleColor()
  ImGui.Separator()
  ImGui.Spacing()
  ImGui.BeginGroup()
  ImGui.AlignTextToFramePadding()
end

function cet_style.sectionHeaderEnd(no_spacing)
  ImGui.EndGroup()
  if not no_spacing then
    ImGui.Spacing()
    ImGui.Spacing()
  end
end

function cet_style.mutedText(text)
  cet_style.styledText(text, cet_style.mutedColor)
end

function cet_style.styledText(text, color, size)
  cet_style.pushStyleColor(color ~= nil, ImGuiCol.Text, color)
  ImGui.SetWindowFontScale(size or 1)
  ImGui.Text(text)
  cet_style.popStyleColor(color ~= nil)
  ImGui.SetWindowFontScale(1)
end

function cet_style.setNextItemWidth(width)
  ImGui.SetNextItemWidth(width * cet_style.viewSize)
end

return cet_style
