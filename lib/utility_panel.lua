--[[
  UtilityPanel — a free-floating draggable panel.
  Used for the lock button; future job-gauge panels extend the same base.

  Callbacks (all optional, set after new()):
    p.on_position_changed(p, x, y)   called when position updates during drag
    p.on_show(p)                      called by p:show()
    p.on_hide(p)                      called by p:hide()
    p.on_destroy(p)                   called by p:destroy()

  on_mouse() return values:
    'content_click'   left-release inside content area  → caller acts on it
    'consumed'        grip drag in progress              → swallow the event
    nil               not handled by this panel
]]

local utility_panel = {}
utility_panel.__index = utility_panel

local GRIP_H   = 10   -- height of the drag handle in pixels
local GRIP_GAP =  2   -- gap between grip bottom and content top

function utility_panel:new(x, y, w, h)
  local p       = setmetatable({}, utility_panel)
  p.x, p.y      = x, y
  p.w, p.h      = w, h
  p.edit_mode   = false
  p.dragging    = false
  p.drag_off_x  = 0
  p.drag_off_y  = 0
  p.visible     = true
  -- When true, clicking anywhere in the content area in edit mode starts a
  -- drag (same as clicking the grip).  Set this on gauge panels so the user
  -- doesn't have to hit the narrow grip strip precisely.  Leave false for the
  -- lock button so its content click still fires toggle_edit_mode.
  p.content_draggable = false

  p.grip_img = images.new({draggable=false, texture={fit=false}}, true)
  p.grip_img:path(windower.addon_path .. '/images/other/grip.png')
  p.grip_img:fit(false)
  p.grip_img:size(w, GRIP_H)
  p.grip_img:pos(x, y - GRIP_H - GRIP_GAP)
  p.grip_img:alpha(210)
  p.grip_img:hide()

  return p
end

function utility_panel:set_position(x, y)
  self.x, self.y = x, y
  self.grip_img:pos(x, y - GRIP_H - GRIP_GAP)
  if self.on_position_changed then self:on_position_changed(x, y) end
end

function utility_panel:set_edit_mode(active)
  self.edit_mode = active
  if active and self.visible then
    self.grip_img:show()
  else
    self.grip_img:hide()
    self.dragging = false
  end
end

function utility_panel:show()
  self.visible = true
  if self.edit_mode then self.grip_img:show() end
  if self.on_show then self:on_show() end
end

function utility_panel:hide()
  self.visible  = false
  self.dragging = false
  self.grip_img:hide()
  if self.on_hide then self:on_hide() end
end

function utility_panel:destroy()
  self.dragging = false
  self.grip_img:hide()
  if self.on_destroy then self:on_destroy() end
end

function utility_panel:is_over_grip(x, y)
  if not self.edit_mode or not self.visible then return false end
  local gx = self.x
  local gy = self.y - GRIP_H - GRIP_GAP
  return x >= gx and x <= gx + self.w
     and y >= gy and y <= gy + GRIP_H
end

function utility_panel:is_over_content(x, y)
  if not self.visible then return false end
  return x >= self.x and x <= self.x + self.w
     and y >= self.y and y <= self.y + self.h
end

function utility_panel:on_mouse(ev_type, x, y)
  if not self.visible then return nil end

  -- Grip drag (edit mode only) ──────────────────────────────────────────────
  if self.edit_mode and ev_type == 1 and self:is_over_grip(x, y) then
    self.dragging   = true
    self.drag_off_x = x - self.x
    self.drag_off_y = y - self.y
    return 'consumed'
  end

  if self.dragging then
    if ev_type == 0 then
      self:set_position(x - self.drag_off_x, y - self.drag_off_y)
      return 'consumed'
    elseif ev_type == 1 or ev_type == 2 then
      if ev_type == 2 then self.dragging = false end
      return 'consumed'
    end
  end

  -- Block grip area even when not dragging (edit mode)
  if self.edit_mode and (ev_type == 1 or ev_type == 2)
                    and self:is_over_grip(x, y) then
    return 'consumed'
  end

  -- Content-area drag in edit mode (gauge panels only, content_draggable=true).
  -- This lets the user grab any part of the gauge to move it, not just the
  -- narrow grip strip — mirrors exactly how the lock button drag works.
  if self.edit_mode and self.content_draggable and ev_type == 1
     and self:is_over_content(x, y) then
    self.dragging   = true
    self.drag_off_x = x - self.x
    self.drag_off_y = y - self.y
    return 'consumed'
  end

  -- Content click — block press AND release; report action on release ────────
  if (ev_type == 1 or ev_type == 2) and self:is_over_content(x, y) then
    return ev_type == 2 and 'content_click' or 'consumed'
  end

  return nil
end

return utility_panel
