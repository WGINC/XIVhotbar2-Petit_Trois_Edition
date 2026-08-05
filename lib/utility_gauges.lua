--[[
  utility_gauges.lua - job-specific HUD panels

  DNC   6 Finishing Move pips
  SCH   Stratagem charge pips, addendum dagger, stratagem symbol row,
        Sublimation ∫ indicator.  Sub-panels are independently positionable
        when the gem gauge is hidden; fused into one draggable unit when shown.
  COR   2 Phantom Roll cards (pre-rendered art, no runtime rotation)
  RUN   Stone arch with rune sockets and recast ring

  All visuals use images.new({draggable=false}).  text objects block the mouse
  handler before Lua sees it, which would break drag entirely.
]]

local utility_gauges = {}
local utility_panel  = require('lib/utility_panel')

-- ── Job IDs ──────────────────────────────────────────────────────────────────
local JOB_DNC = 19
local JOB_SCH = 20
local JOB_COR = 17
local JOB_RUN = 22

local function has_job(player, id)
  return player.main_job_id == id or player.sub_job_id == id
end

-- ── Shared pip helpers ───────────────────────────────────────────────────────
local PIP_W   = 10
local PIP_H   = 10
local PIP_GAP =  3

local function pip_row_width(n)  return n * PIP_W + (n - 1) * PIP_GAP  end

local function make_pip(x, y)
  local img = images.new({draggable=false, texture={fit=false}}, true)
  img:path(windower.addon_path .. '/images/other/pip.png')
  img:fit(false); img:size(PIP_W, PIP_H); img:pos(x, y); img:hide()
  return img
end

local function make_pip_row(bx, by, n)
  local pips = {}
  for i = 1, n do
    pips[i] = make_pip(bx + (i-1)*(PIP_W+PIP_GAP), by)
  end
  return pips
end

local function reposition_pip_row(pips, nx, ny)
  for i, p in ipairs(pips) do
    p:pos(nx + (i-1)*(PIP_W+PIP_GAP), ny)
  end
end

local function hide_pips(pips)  for _, p in ipairs(pips) do p:hide() end  end

local function draw_pips(pips, count, max, fr, fg, fb)
  for i = 1, max do
    if i <= count then pips[i]:color(fr,fg,fb); pips[i]:alpha(255)
    else               pips[i]:color(35,35,35); pips[i]:alpha(130)
    end
    pips[i]:show()
  end
end

-- ── DNC Finishing Move gauge ─────────────────────────────────────────────────
local DNC_N = 6
local DNC_R, DNC_G, DNC_B = 80, 215, 155

local function create_dnc_panel(x, y)
  local panel = utility_panel:new(x, y, pip_row_width(DNC_N), PIP_H)
  panel.content_draggable = true
  panel.pips = make_pip_row(x, y, DNC_N)
  panel.fm   = 0

  panel.on_position_changed = function(p, nx, ny) reposition_pip_row(p.pips, nx, ny) end
  panel.on_show    = function(p) p:render() end
  panel.on_hide    = function(p) hide_pips(p.pips) end
  panel.on_destroy = function(p) hide_pips(p.pips) end

  function panel:render(count)
    if count ~= nil then self.fm = count end
    if not self.visible then return end
    draw_pips(self.pips, self.fm, DNC_N, DNC_R, DNC_G, DNC_B)
  end

  return panel
end

-- ── SCH ────────────────────────────────────────────────────────────────────────
local SCH_STRAT_RECAST_ID     = 231
local SCH_MAX_PIPS            = 5
local SCH_ADDENDUM_WHITE_BUFF = 401
local SCH_ADDENDUM_BLACK_BUFF = 402

-- Dagger  source 120×180 px, displayed 36×54
local SCH_DAGGER_W    = 36
local SCH_DAGGER_H    = 54
local SCH_DAGGER_GAP  = 4
local SCH_PIP_OFFSET  = SCH_DAGGER_W + SCH_DAGGER_GAP   -- 32

-- slide-in animation: 20-frame smoothstep driven by prerender tick
local SCH_DAGGER_ANIM_TOTAL = 20
local SCH_DAGGER_SLIDE_PX   = 30
local sch_dagger_anim_frame = SCH_DAGGER_ANIM_TOTAL
local sch_addendum_prev     = false

-- Sublimation ∫  source 201×274 px
local SCH_SUBLIM_W    = 34   -- display px (source 201×274)
local SCH_SUBLIM_H    = 82
local SCH_SUBLIM_GAP  = 2    -- flush to gauge right edge

-- buff IDs populated lazily; resources.buffs not safe at module load
local SCH_SUBLIM_IDS    = {}   -- buff_id → 'charge' | 'ready'
local sch_sublim_built  = false

-- visibility flags (all default on; read from settings in setup())
local sch_show_gauge  = true
local sch_show_gems   = true
local sch_show_strats = true
local sch_show_sublim  = true
local sch_show_dagger  = true
local sch_sym_panel    = nil

-- gem gauge  display px; source PNGs 2×
local SCH_GAUGE_W = 235
local SCH_GAUGE_H = 77
local SCH_GEM_W   = 46
local SCH_GEM_H   = 46
local SCH_SLOT_XS = {38, 76, 114, 152, 190}
local SCH_GEM_DY  = 14    -- gem top: slot_centre_y(40) - half_gem(23) ≈ 14

-- stratagem symbols  source 60×60, display 32×32
-- light/dark pairs share slot positions 0–6; only one set visible at a time
local SCH_SYM_W       = 32
local SCH_SYM_H       = 32
local SCH_SYM_HGAP    = 2
local SCH_SYM_VOFFSET = 4    -- gap between symbol bottom and gauge top
local SCH_SYM_ROW_DY  = -(32 + 4)   -- = -36

-- [1–7] light arts, [8–14] dark arts - same 7 display slots
local SCH_STRAT_LIST = {
  -- ── Light Arts (White Grimoire) ──────────────────────────
  {'penury',      'sch_sym_penury.png'},       -- slot 0: MP cost reduction
  {'celerity',    'sch_sym_celerity.png'},      -- slot 1: cast speed
  {'accession',   'sch_sym_accession.png'},     -- slot 2: AoE white magic
  {'rapture',     'sch_sym_rapture.png'},       -- slot 3: healing enhancement
  {'altruism',    'sch_sym_altruism.png'},      -- slot 4: enhancing magic (merit)
  {'tranquility', 'sch_sym_tranquility.png'},   -- slot 5: elemental (merit)
  {'perpetuance', 'sch_sym_perpetuance.png'},   -- slot 6: buff duration
  -- ── Dark Arts (Black Grimoire) ───────────────────────────
  {'parsimony',     'sch_sym_parsimony.png'},      -- slot 0: MP cost reduction
  {'alacrity',      'sch_sym_alacrity.png'},        -- slot 1: recast speed
  {'manifestation', 'sch_sym_manifestation.png'},   -- slot 2: AoE black magic
  {'ebullience',    'sch_sym_ebullience.png'},       -- slot 3: magic attack
  {'focalization',  'sch_sym_focalization.png'},     -- slot 4: cast speed (merit)
  {'equanimity',    'sch_sym_equanimity.png'},       -- slot 5: MP cost (merit)
  {'immanence',     'sch_sym_immanence.png'},        -- slot 6: elemental enhancement
}

local SCH_STRAT_IDX = {}
for i, v in ipairs(SCH_STRAT_LIST) do SCH_STRAT_IDX[v[1]] = i end
local SCH_BUFF_TO_STRAT_CACHE = {}  -- buff_id → name; filled on first render

-- symbol row x-start, centred over the gauge background
local function sch_sym_x0(gx)
  return gx + math.floor((SCH_GAUGE_W - (7*SCH_SYM_W + 6*SCH_SYM_HGAP)) / 2)
end

-- module-scope: survives panel recreation on arts/addendum changes
local sch_used       = 0
local sch_next_regen = nil

-- ── Accessibility / colorblind palette ───────────────────────────────────────
-- 'colorblind' covers red-green deficiency (deuteranopia, protanopia).
-- All keys: light_arts, dark_arts, sublim_charge, sublim_ready
local SCH_PALETTE = {
  off = {
    light_arts    = {80,  140, 220},   -- blue   / Light Arts
    dark_arts     = {155,  75, 215},   -- purple / Dark Arts
    sublim_charge = {255,  80,  60},   -- red    (HP draining)
    sublim_ready  = { 60, 220, 100},   -- green  (pool full)
  },
  colorblind = {
    light_arts    = { 30, 140, 255},   -- blue
    dark_arts     = {255, 165,   0},   -- amber
    sublim_charge = {255, 165,   0},   -- amber  (draining)
    sublim_ready  = { 30, 140, 255},   -- blue   (ready)
  },
  grayscale = {
    light_arts    = {230, 230, 230},
    dark_arts     = {110, 110, 110},
    sublim_charge = {150, 150, 150},
    sublim_ready  = {255, 255, 255},
  },
}

local sch_a11y_mode = 'off'

local function sch_pal(key)
  local p = SCH_PALETTE[sch_a11y_mode] or SCH_PALETTE.off
  local c = p[key] or SCH_PALETTE.off[key]
  return c[1], c[2], c[3]
end

local function sch_max_charges(level)
  if     level >= 90 then return 5
  elseif level >= 70 then return 4
  elseif level >= 50 then return 3
  elseif level >= 30 then return 2
  elseif level >= 10 then return 1
  else                     return 0
  end
end
local function sch_seconds_per_charge(pd, max)
  local jp = pd and pd.job_points and pd.job_points.sch and pd.job_points.sch.jp_spent or 0
  local full_cycle = jp > 549 and 165 or 240
  return full_cycle / max
end
local function sch_current_charges(pd, max)
  local spc = sch_seconds_per_charge(pd, max)
  local now = os.clock()
  while sch_used > 0 and sch_next_regen and now >= sch_next_regen do
    sch_used = sch_used - 1
    sch_next_regen = sch_used > 0 and (sch_next_regen + spc) or nil
  end
  if sch_used == 0 and sch_next_regen == nil then
    -- seed one charge from live recast on first call
    local recasts   = windower.ffxi.get_ability_recasts()
    local remaining = (recasts and recasts[SCH_STRAT_RECAST_ID] or 0) / 60
    if remaining > 0 then
      sch_used       = 1
      sch_next_regen = now + remaining
    end
  end
  return max - math.min(sch_used, max)
end

local function make_dagger(x, y)
  local img = images.new({draggable=false, texture={fit=false}})
  img:path(windower.addon_path .. '/images/other/dagger.png')
  img:fit(false); img:size(SCH_DAGGER_W, SCH_DAGGER_H); img:pos(x, y); img:hide()
  return img
end

local function sch_fuse_positions(gem_x, gem_y)
  local row_w = 7*SCH_SYM_W + 6*SCH_SYM_HGAP
  local gx    = gem_x + SCH_PIP_OFFSET
  return gem_x, gem_y + math.floor((SCH_GAUGE_H-SCH_DAGGER_H)/2),
         gem_x + SCH_PIP_OFFSET + math.floor((SCH_GAUGE_W-row_w)/2),
         gem_y - SCH_SYM_H - SCH_SYM_VOFFSET,
         gx + SCH_GAUGE_W + SCH_SUBLIM_GAP,
         gem_y + math.floor((SCH_GAUGE_H-SCH_SUBLIM_H)/2)
end
local function sch_apply_fuse(gem_x, gem_y)
  local dx,dy,sx,sy,slx,sly = sch_fuse_positions(gem_x, gem_y)
  if sch_dagger_panel then sch_dagger_panel:set_position(dx, dy)   end
  if sch_sym_panel    then sch_sym_panel:set_position(sx, sy)       end
  if sch_sublim_panel then sch_sublim_panel:set_position(slx, sly) end
end
local function sch_apply_unfuse()
  sch_fused = false
  local function go(p, ix, iy) if p and (ix~=0 or iy~=0) then p:set_position(ix,iy) end end
  go(sch_sym_panel,    sch_sym_ind_x,    sch_sym_ind_y)
  go(sch_dagger_panel, sch_dagger_ind_x, sch_dagger_ind_y)
  go(sch_sublim_panel, sch_sublim_ind_x, sch_sublim_ind_y)
  if sch_edit_active then
    if sch_sym_panel    then sch_sym_panel:set_edit_mode(true)    end
    if sch_dagger_panel then sch_dagger_panel:set_edit_mode(true) end
    if sch_sublim_panel then sch_sublim_panel:set_edit_mode(true) end
  end
end

-- ── Stratagem symbol row - independent draggable panel ───────────────────────
local function create_sch_sym_panel(x, y)
  local row_w = 7 * SCH_SYM_W + 6 * SCH_SYM_HGAP
  local panel = utility_panel:new(x, y, row_w, SCH_SYM_H)
  panel.content_draggable = true
  panel.syms = {}
  for i, strat in ipairs(SCH_STRAT_LIST) do
    local slot = (i <= 7) and (i - 1) or (i - 8)
    local img  = images.new({draggable=false, texture={fit=false}})
    img:path(windower.addon_path .. '/images/sch/' .. strat[2])
    img:fit(false); img:size(SCH_SYM_W, SCH_SYM_H)
    img:pos(x + slot*(SCH_SYM_W+SCH_SYM_HGAP), y); img:hide()
    panel.syms[i] = img
  end
  local function repos(p, nx, ny)
    for i = 1, #SCH_STRAT_LIST do
      if p.syms[i] then
        local slot = (i <= 7) and (i-1) or (i-8)
        p.syms[i]:pos(nx + slot*(SCH_SYM_W+SCH_SYM_HGAP), ny)
      end
    end
  end
  local function hsyms(p)
    for i = 1, #SCH_STRAT_LIST do if p.syms[i] then p.syms[i]:hide() end end
  end
  panel.on_position_changed = repos
  panel.on_show    = function(p) p:render() end
  panel.on_hide    = hsyms
  panel.on_destroy = hsyms
  function panel:render()
    if not self.visible or not self.syms then return end
    if not sch_show_strats then
      for i = 1, #SCH_STRAT_LIST do if self.syms[i] then self.syms[i]:hide() end end
      return
    end
    local dark = false
    local pd   = windower.ffxi.get_player()
    if pd and pd.buffs then
      for _, b in ipairs(pd.buffs) do
        if b == 359 or b == SCH_ADDENDUM_BLACK_BUFF then dark = true; break end
      end
    end
    local active = {}; local br = type(resources)=='table' and resources.buffs
    if pd and pd.buffs then
      for _, bid in ipairs(pd.buffs) do
        local name = SCH_BUFF_TO_STRAT_CACHE[bid]
        if not name and br then
          local b2 = br[bid]
          if b2 and b2.en then
            name = b2.en:lower()
            if not SCH_STRAT_IDX[name] then name = nil end
            if name then SCH_BUFF_TO_STRAT_CACHE[bid] = name end
          end
        end
        if name then active[name] = true end
      end
    end
    for i, strat in ipairs(SCH_STRAT_LIST) do
      local img = self.syms[i]
      if img then
        if ((i>7)==dark) and active[strat[1]] then img:show() else img:hide() end
      end
    end
  end
  return panel
end

-- ── Dagger indicator - independent draggable panel ───────────────────────────
local function create_sch_dagger_panel(x, y)
  local panel = utility_panel:new(x, y, SCH_DAGGER_W, SCH_DAGGER_H)
  panel.content_draggable = true
  local img = images.new({draggable=false, texture={fit=false}})
  img:path(windower.addon_path .. '/images/other/dagger.png')
  img:fit(false); img:size(SCH_DAGGER_W, SCH_DAGGER_H); img:pos(x, y); img:hide()
  panel.dagger = img
  panel.on_position_changed = function(p, nx, ny) p.dagger:pos(nx, ny) end
  local function hd(p) if p.dagger then p.dagger:hide() end end
  panel.on_hide    = hd
  panel.on_destroy = hd
  panel.on_show    = function(p) p:render() end
  function panel:render()
    if not self.visible or not self.dagger then return end
    local dark, addendum = false, false
    local pd = windower.ffxi.get_player()
    if pd and pd.buffs then
      for _, b in ipairs(pd.buffs) do
        if b == 359 or b == SCH_ADDENDUM_BLACK_BUFF then dark = true end
        if b == SCH_ADDENDUM_WHITE_BUFF or b == SCH_ADDENDUM_BLACK_BUFF then addendum = true end
      end
    end
    local dr, dg, db = sch_pal(dark and 'dark_arts' or 'light_arts')
    local was = sch_addendum_prev
    sch_addendum_prev = addendum
    if addendum and sch_show_dagger and sch_show_gauge then
      self.dagger:color(dr, dg, db); self.dagger:alpha(255)
      if not was then
        self.dagger:pos(self.x, self.y - SCH_DAGGER_SLIDE_PX)
        sch_dagger_anim_frame = 0
      end
      self.dagger:show()
    else
      self.dagger:hide()
    end
  end
  return panel
end

-- ── Sublimation indicator - independent draggable panel ──────────────────────
local function create_sch_sublim_panel(x, y)
  local panel = utility_panel:new(x, y, SCH_SUBLIM_W, SCH_SUBLIM_H)
  panel.content_draggable = true
  local img = images.new({draggable=false, texture={fit=false}})
  img:path(windower.addon_path .. '/images/sch/sch_sublim.png')
  img:fit(false); img:size(SCH_SUBLIM_W, SCH_SUBLIM_H); img:pos(x, y); img:hide()
  panel.sublim = img
  panel.on_position_changed = function(p, nx, ny) if p.sublim then p.sublim:pos(nx, ny) end end
  local function hs(p) if p.sublim then p.sublim:hide() end end
  panel.on_hide    = hs
  panel.on_destroy = hs
  panel.on_show    = function(p) p:render() end
  function panel:render()
    if not self.visible or not self.sublim then return end
    if not sch_show_sublim or not sch_show_gauge then self.sublim:hide(); return end
    if not sch_sublim_built then
      sch_sublim_built = true
      local br = type(resources) == 'table' and resources.buffs
      if br then
        for id, buff in pairs(br) do
          if buff and buff.en then
            local en = buff.en:lower()
            if en:find('sublimation') then
              SCH_SUBLIM_IDS[id] = en:find('complet') and 'ready' or 'charge'
            end
          end
        end
      end
    end
    local pd = windower.ffxi.get_player()
    local state = nil
    if pd and pd.buffs then
      for _, bid in ipairs(pd.buffs) do
        local s = SCH_SUBLIM_IDS[bid]
        if s == 'ready'  then state = 'ready';  break end
        if s == 'charge' then state = 'charge' end
      end
    end
    -- ∮ (contour integral) only while charging in an a11y mode; ∫ otherwise
    local icon = (sch_a11y_mode ~= 'off' and state == 'charge')
                 and 'sch_sublim_a11y.png' or 'sch_sublim.png'
    if self._sublim_icon ~= icon then
      self.sublim:path(windower.addon_path .. '/images/sch/' .. icon)
      self.sublim:size(SCH_SUBLIM_W, SCH_SUBLIM_H)  -- path() resets size; restore
      self._sublim_icon = icon
    end
    if state == 'ready' then
      local r,g,b = sch_pal('sublim_ready')
      self.sublim:color(r,g,b); self.sublim:alpha(255); self.sublim:show()
    elseif state == 'charge' then
      local r,g,b = sch_pal('sublim_charge')
      self.sublim:color(r,g,b); self.sublim:alpha(255); self.sublim:show()
    else
      self.sublim:hide()
    end
  end
  return panel
end

local function create_sch_panel(x, y)
  local gx = x + SCH_PIP_OFFSET

  local panel = utility_panel:new(x, y, SCH_PIP_OFFSET + SCH_GAUGE_W, SCH_GAUGE_H)
  panel.content_draggable = true

  -- Gauge background
  local bg = images.new({draggable=false, texture={fit=false}})
  bg:path(windower.addon_path .. '/images/sch/sch_gauge_bg.png')
  bg:fit(false); bg:size(SCH_GAUGE_W, SCH_GAUGE_H); bg:pos(gx, y); bg:show()
  panel.bg = bg


  -- Gem pips (filled / empty pair per slot)
  panel.gems_on  = {}
  panel.gems_off = {}
  for i = 1, SCH_MAX_PIPS do
    local gpx = gx + SCH_SLOT_XS[i] - math.floor(SCH_GEM_W / 2)
    local gpy = y + SCH_GEM_DY
    local on_img = images.new({draggable=false, texture={fit=false}})
    on_img:path(windower.addon_path .. '/images/sch/sch_pip_on.png')
    on_img:fit(false); on_img:size(SCH_GEM_W, SCH_GEM_H); on_img:pos(gpx, gpy); on_img:hide()
    panel.gems_on[i] = on_img
    local off_img = images.new({draggable=false, texture={fit=false}})
    off_img:path(windower.addon_path .. '/images/sch/sch_pip_off.png')
    off_img:fit(false); off_img:size(SCH_GEM_W, SCH_GEM_H); off_img:pos(gpx, gpy); off_img:hide()
    panel.gems_off[i] = off_img
  end

  -- sym/dagger/sublim each have their own independent panel


  local function reposition_all(p, nx, ny)
    local ngx = nx + SCH_PIP_OFFSET
    p.bg:pos(ngx, ny)
    for i = 1, SCH_MAX_PIPS do
      local gpx = ngx + SCH_SLOT_XS[i] - math.floor(SCH_GEM_W / 2)
      p.gems_on[i]:pos(gpx, ny + SCH_GEM_DY)
      p.gems_off[i]:pos(gpx, ny + SCH_GEM_DY)
    end
    if sch_fused then sch_apply_fuse(nx, ny) end
  end

  local function hide_all_sch(p)
    if p.bg    then p.bg:hide()    end
    if p.gems_on  then for i = 1, SCH_MAX_PIPS do if p.gems_on[i]  then p.gems_on[i]:hide()  end end end
    if p.gems_off then for i = 1, SCH_MAX_PIPS do if p.gems_off[i] then p.gems_off[i]:hide() end end end
  end

  panel.on_position_changed = reposition_all
  panel.on_show    = function(p) p:render() end
  panel.on_hide    = hide_all_sch
  panel.on_destroy = hide_all_sch

  -- Called from on_action when any recast_id-231 ability fires.
  function panel:note_charge_used()
    local pd    = windower.ffxi.get_player()
    local level = pd and (pd.main_job_id == JOB_SCH and pd.main_job_level or pd.sub_job_id == JOB_SCH and pd.sub_job_level or 0) or 0
    local max   = sch_max_charges(level or 0)
    if sch_used >= max then return end
    sch_used = sch_used + 1
    if sch_next_regen == nil then
      sch_next_regen = os.clock() + sch_seconds_per_charge(pd, max)
    end
  end

  function panel:render()
    if not self.visible then return end
    -- skip if images.new failed mid-construction
    if not self.gems_on or not self.bg then return end
    local pd = windower.ffxi.get_player()
    local level = pd and (pd.main_job_id == JOB_SCH and pd.main_job_level or pd.sub_job_id == JOB_SCH and pd.sub_job_level or 0) or 0
    local max   = sch_max_charges(level or 0)
    local cur   = max > 0 and sch_current_charges(pd, max) or 0

    -- Master toggle: hide everything and bail
    if not sch_show_gauge then
      self.bg:hide()
      for i = 1, SCH_MAX_PIPS do
        if self.gems_on[i]  then self.gems_on[i]:hide()  end
        if self.gems_off[i] then self.gems_off[i]:hide() end
      end
      return
    end

    if sch_show_gems then self.bg:show() else self.bg:hide() end

    -- Gem pips
    for i = 1, SCH_MAX_PIPS do
      if sch_show_gems and i <= max and i <= cur then
        self.gems_on[i]:show()
      else
        self.gems_on[i]:hide()
      end
      self.gems_off[i]:hide()
    end



  end

  return panel
end

-- ── COR Phantom Roll gauge - two overlapping "playing cards" ─────────────────
--
-- Layout: two cards arranged like a hand, right card overlapping left.
-- All visuals are images.new({draggable=false}) - no texts.new() anywhere.
-- text objects set blocked=true before the
-- Lua mouse handler runs, permanently preventing content drag from working.
-- Image objects with draggable=false never block events, matching how the
-- lock button panel is built.
--
-- Z-order (creation order = draw order, later = on top):
--   card1_bg < card1_nums < card2_bg < card2_nums
-- This causes card2 to correctly overlay the overlap region of card1.

-- Buff IDs from Windower/Resources/resources_data/buffs.lua
-- 309 = Bust (debuff) - excluded; active rolls are 310-338
local COR_ROLL_BUFFS = {
  [310]='Fght', [311]='Mnk',  [312]='Heal', [313]='Wiz',  [314]='Wrlk',
  [315]='Rog',  [316]='Gal',  [317]='Chaos',[318]='Beast',[319]='Choral',
  [320]='Hunt', [321]='Sam',  [322]='Nin',  [323]='Drag', [324]='Evo',
  [325]='Mag',  [326]='Cor',  [327]='Pup',  [328]='Dnc',  [329]='Sch',
  [330]='Bltr', [331]='Cstr', [332]='Crsr', [333]='Bltz', [334]='Tact',
  [335]='Ally', [336]='Msr',  [337]='Comp', [338]='Avg',
  -- These two were added later (GEO/RUN, Seekers of Adoulin) and don't sit
  -- in the original contiguous 310-338 block, which is why both the old
  -- range check here and the one in on_action() silently dropped them --
  -- Naturalist's Roll showing nothing was that bug. Buff IDs confirmed
  -- against Windower/Resources/resources_data/buffs.lua and AutoCOR's
  -- roll table (Ivaar/Windower-addons).
  [339]='Natu', [600]='Rune',
}

-- act.param -> buff_id, used by on_action() to instantly catch the roll
-- number off the action packet (scan_roll_buff handles steady-state display
-- independently of this). This used to be computed as "act.param + 212",
-- which happens to hold for ability ids 98-122 (the original 21 rolls) but
-- silently breaks for ids 302-305 (Allies'/Miser's/Companion's/Avenger's --
-- a pre-existing bug, not something introduced here) and again for 390-391
-- (Naturalist's/Runeist's). All of this is now an explicit table sourced
-- directly from Windower/Resources/resources_data/job_abilities.lua rather
-- than an arithmetic guess.
local COR_ROLL_PARAMS = {
  [98]=310,  [99]=311,  [100]=312, [101]=313, [102]=314, [103]=315,
  [104]=316, [105]=317, [106]=318, [107]=319, [108]=320, [109]=321,
  [110]=322, [111]=323, [112]=324, [113]=325, [114]=326, [115]=327,
  [116]=328, [117]=329, [118]=330, [119]=331, [120]=332, [121]=333,
  [122]=334,
  [302]=335, [303]=336, [304]=337, [305]=338,
  [390]=339, [391]=600,
}

local COR_LUCKY = {
  [310]={l=5,u=9},  [311]={l=3,u=7},  [312]={l=3,u=7},  [313]={l=5,u=9},
  [314]={l=4,u=8},  [315]={l=5,u=9},  [316]={l=3,u=7},  [317]={l=4,u=8},
  [318]={l=4,u=8},  [319]={l=2,u=6},  [320]={l=4,u=8},  [321]={l=2,u=6},
  [322]={l=4,u=8},  [323]={l=4,u=8},  [324]={l=5,u=9},  [325]={l=3,u=7},
  [326]={l=5,u=9},  [327]={l=4,u=8},  [328]={l=3,u=7},  [329]={l=5,u=9},
  [330]={l=3,u=7},  [331]={l=2,u=6},  [332]={l=4,u=8},  [333]={l=4,u=8},
  [334]={l=5,u=9},  [335]={l=3,u=7},  [336]={l=5,u=9},  [337]={l=4,u=8},
  [338]={l=4,u=8},
  [339]={l=3,u=7},  -- Naturalist's Roll
  [600]={l=4,u=8},  -- Runeist's Roll
}

local function num_color(buff_id, n)
  local lk = buff_id and COR_LUCKY[buff_id]
  if lk and n == lk.l then return  90, 235,  90 end  -- lucky  (green)
  if lk and n == lk.u then return 235,  75,  75 end  -- unlucky (red)
  return 255, 210, 60                                   -- normal  (gold)
end

-- Card geometry - two tilted cards in a fanned hand.
-- Back card (left):  card_back.png  60×74, rotated -12° (top leans left)
-- Front card (right): card_front.png 52×68, rotated +4°  (top leans right)
-- Panel origin is the top-left of the overall bounding box.
local BACK_W,  BACK_H  = 60, 74   -- card_back.png  dimensions
local FRONT_W, FRONT_H = 52, 68   -- card_front.png dimensions
local NUM_BW,  NUM_BH  = 44, 50   -- num_N_back.png dimensions
local NUM_FW,  NUM_FH  = 40, 46   -- num_N_front.png dimensions
-- Roll-name labels - rendered the exact same way as the roll numbers: one
-- pre-rotated, pre-rendered white glyph image per roll name (matching the
-- card's tilt), tinted at runtime via :color(). Images are used instead of
-- texts.new() for the same reason the numbers are - text objects set
-- blocked=true before our Lua mouse handler runs, which would break drag.
local NAME_BW, NAME_BH = 59, 32   -- name_<Key>_back.png  dimensions
local NAME_FW, NAME_FH = 50, 20   -- name_<Key>_front.png dimensions
local NAME_TOP_MARGIN  = 1        -- gap from the top edge of the card
-- Title color stays fixed (not luck-tinted like the number) - the baked-in
-- dark outline (see image generation) does the contrast work against the
-- white card art regardless of this tint.
local NAME_COLOR_R, NAME_COLOR_G, NAME_COLOR_B = 235, 225, 200
-- Insets that centre each number image on its card
local NUM_BINS_X = (BACK_W  - NUM_BW) / 2   -- = 8
local NUM_BINS_Y = (BACK_H  - NUM_BH) / 2   -- = 12
local NUM_FINS_X = (FRONT_W - NUM_FW) / 2   -- = 6
local NUM_FINS_Y = (FRONT_H - NUM_FH) / 2   -- = 11
local NAME_BINS_X = (BACK_W  - NAME_BW) / 2  -- centre name on back card
local NAME_FINS_X = (FRONT_W - NAME_FW) / 2  -- centre name on front card
-- Back card anchor relative to panel origin
local BACK_OFF_X  = 0
local BACK_OFF_Y  = 14  -- back card sits 14 px lower (fan depth)
-- Front card anchor relative to panel origin
local FRONT_OFF_X = 32  -- front card starts 32 px right
local FRONT_OFF_Y = 0
local MAX_ROLLS   = 2
local COR_PANEL_W = FRONT_OFF_X + FRONT_W   -- = 84
local COR_PANEL_H = BACK_OFF_Y  + BACK_H    -- = 88

local function make_card_img(which, x, y)
  -- which: 'back' or 'front'
  local file = which == 'back' and 'card_back.png' or 'card_front.png'
  local w    = which == 'back' and BACK_W     or FRONT_W
  local h    = which == 'back' and BACK_H     or FRONT_H
  local img  = images.new({draggable=false, texture={fit=false}}, true)
  img:path(windower.addon_path .. '/images/cor/' .. file)
  img:fit(false); img:size(w, h); img:pos(x, y); img:alpha(235); img:hide()
  return img
end

local function make_num_img(which, n, x, y)
  -- which: 'back' or 'front'
  local suffix = which == 'back' and '_back.png' or '_front.png'
  local w      = which == 'back' and NUM_BW or NUM_FW
  local h      = which == 'back' and NUM_BH or NUM_FH
  local img    = images.new({draggable=false, texture={fit=false}}, true)
  img:path(windower.addon_path .. '/images/cor/num_' .. tostring(n) .. suffix)
  img:fit(false); img:size(w, h); img:pos(x, y)
  img:color(255, 210, 60); img:alpha(255); img:hide()
  return img
end

local function make_name_img(which, x, y)
  -- which: 'back' or 'front'. No initial path - the roll name isn't known
  -- until a roll is active, so render() swaps the path via :path() the
  -- same way the lock button swaps between lock.png/unlock.png.
  local w   = which == 'back' and NAME_BW or NAME_FW
  local h   = which == 'back' and NAME_BH or NAME_FH
  local img = images.new({draggable=false, texture={fit=false}}, true)
  img:fit(false); img:size(w, h); img:pos(x, y)
  img:color(NAME_COLOR_R, NAME_COLOR_G, NAME_COLOR_B); img:alpha(255); img:hide()
  return img
end

local function create_cor_panel(x, y)
  local panel = utility_panel:new(x, y, COR_PANEL_W, COR_PANEL_H)
  panel.content_draggable = true
  panel.rolls       = {}
  panel.pending_num = nil
  panel.pending_bid = nil   -- which roll buff_id the pending number belongs to

  -- Build in Z-order: back bg, back nums, front bg, front nums.
  -- This ensures the front card correctly overlaps the back card.
  local cbx = x + BACK_OFF_X
  local cby = y + BACK_OFF_Y
  local cfx = x + FRONT_OFF_X
  local cfy = y + FRONT_OFF_Y

  local cards = {}

  cards[1] = { bg = make_card_img('back',  cbx, cby), nums = {} }
  for n = 1, 11 do
    cards[1].nums[n] = make_num_img('back',  n, cbx + NUM_BINS_X, cby + NUM_BINS_Y)
  end
  cards[1].name = make_name_img('back', cbx + NAME_BINS_X, cby + NAME_TOP_MARGIN)

  cards[2] = { bg = make_card_img('front', cfx, cfy), nums = {} }
  for n = 1, 11 do
    cards[2].nums[n] = make_num_img('front', n, cfx + NUM_FINS_X, cfy + NUM_FINS_Y)
  end
  cards[2].name = make_name_img('front', cfx + NAME_FINS_X, cfy + NAME_TOP_MARGIN)

  panel.cards = cards

  local function place(p, nx, ny)
    local nbx = nx + BACK_OFF_X;  local nby = ny + BACK_OFF_Y
    local nfx = nx + FRONT_OFF_X; local nfy = ny + FRONT_OFF_Y
    p.cards[1].bg:pos(nbx, nby)
    for n = 1, 11 do p.cards[1].nums[n]:pos(nbx + NUM_BINS_X, nby + NUM_BINS_Y) end
    p.cards[1].name:pos(nbx + NAME_BINS_X, nby + NAME_TOP_MARGIN)
    p.cards[2].bg:pos(nfx, nfy)
    for n = 1, 11 do p.cards[2].nums[n]:pos(nfx + NUM_FINS_X, nfy + NUM_FINS_Y) end
    p.cards[2].name:pos(nfx + NAME_FINS_X, nfy + NAME_TOP_MARGIN)
  end

  panel.on_position_changed = function(p, nx, ny) place(p, nx, ny) end

  panel.on_show = function(p)
    p.cards[1].bg:show(); p.cards[2].bg:show()
    p:render()
  end

  panel.on_hide = function(p)
    for i = 1, MAX_ROLLS do
      p.cards[i].bg:hide()
      p.cards[i].name:hide()
      for n = 1, 11 do p.cards[i].nums[n]:hide() end
    end
  end

  panel.on_destroy = function(p)
    for i = 1, MAX_ROLLS do
      p.cards[i].bg:hide()
      p.cards[i].name:hide()
      for n = 1, 11 do p.cards[i].nums[n]:hide() end
    end
  end

  function panel:scan_roll_buff()
    local pd = windower.ffxi.get_player()
    if not pd then return end
    local buffs = pd.buffs or {}

    local active_ids = {}
    for _, b in ipairs(buffs) do
      -- COR_ROLL_BUFFS is now the single source of truth for valid roll
      -- buff IDs (it includes the non-contiguous 339/600 entries), so a
      -- separate numeric range here would just re-introduce the bug where
      -- Naturalist's/Runeist's Roll got silently dropped.
      if COR_ROLL_BUFFS[b] and #active_ids < MAX_ROLLS then
        table.insert(active_ids, b)
      end
    end

    local new_rolls = {}
    for _, bid in ipairs(active_ids) do
      local num = 0
      for _, r in ipairs(self.rolls) do
        if r.buff_id == bid then num = r.num; break end
      end
      -- Consume pending_num only when it belongs to this exact buff_id.
      -- This prevents assigning a Phantom Roll result to the wrong slot.
      if self.pending_bid == bid and self.pending_num then
        num = self.pending_num
        self.pending_num = nil
        self.pending_bid = nil
      end
      table.insert(new_rolls, {buff_id=bid, num=num})
    end

    -- If the expected buff never appeared (Bust, Fold, etc.), discard stale state.
    if self.pending_bid then
      local still_active = false
      for _, bid in ipairs(active_ids) do
        if bid == self.pending_bid then still_active = true; break end
      end
      if not still_active then
        self.pending_num = nil; self.pending_bid = nil
      end
    end

    self.rolls = new_rolls
    self:render()
  end

  -- Called from on_action with the exact buff_id (looked up via
  -- COR_ROLL_PARAMS, not computed) and whether this is a Double-Up
  -- (message 424) or a new Phantom Roll (420).
  -- Double-Up updates the existing roll directly; new rolls store a
  -- buff-id-keyed pending that scan_roll_buff assigns when the buff appears.
  function panel:apply_roll(buff_id, result, is_doubleup)
    if is_doubleup then
      -- Double-Up never creates a new buff - it updates the existing one.
      -- Update in-place without waiting for a buff-change event.
      for _, r in ipairs(self.rolls) do
        if r.buff_id == buff_id then
          r.num = result
          self:render()
          return
        end
      end
      -- If somehow not tracked yet, fall through to pending path below.
    end
    -- New Phantom Roll: buff hasn't appeared yet.  Store keyed to buff_id
    -- so scan_roll_buff can assign to exactly the right slot.
    self.pending_num = result
    self.pending_bid = buff_id
  end

  function panel:render()
    if not self.visible then return end
    -- Belt-and-suspenders: always re-anchor to stored position
    place(self, self.x, self.y)

    for i = 1, MAX_ROLLS do
      local roll = self.rolls[i]
      local card = self.cards[i]
      local side_suffix = i == 1 and '_back.png' or '_front.png'
      if roll then
        card.bg:alpha(235); card.bg:show()
        local cr, cg, cb = num_color(roll.buff_id, roll.num)
        for n = 1, 11 do
          if n == roll.num and roll.num > 0 then
            card.nums[n]:color(cr, cg, cb); card.nums[n]:show()
          else
            card.nums[n]:hide()
          end
        end
        local key = COR_ROLL_BUFFS[roll.buff_id]
        if key then
          card.name:path(windower.addon_path .. '/images/cor/name_' .. key .. side_suffix)
          card.name:color(NAME_COLOR_R, NAME_COLOR_G, NAME_COLOR_B); card.name:show()
        else
          card.name:hide()
        end
      else
        card.bg:alpha(60); card.bg:show()
        card.name:hide()
        for n = 1, 11 do card.nums[n]:hide() end
      end
    end
  end

  return panel
end

-- ── RUN Rune gauge - 3 rune tablets in an arch, recast ring below ───────────
-- Buff IDs from Windower/Resources/resources_data/buffs.lua (523-530)
local RUN_N = 3
-- Each glyph image is final art with its element's color already baked in
-- (a glowing sigil rendered on black), the same "fixed color, no runtime
-- tint" convention used for the COR card name labels. RUNE_GLYPH doubles
-- as the rune-buff membership test (on_action/render check it for
-- presence, not just to resolve the filename).
local RUNE_GLYPH = {
  [523]='ignis', [524]='gelus',  [525]='flabra', [526]='tellus',
  [527]='sulpor',[528]='unda',   [529]='lux',    [530]='tenebrae',
}

-- The 8 rune abilities (Ignis..Tenebrae, ids 358-365) share recast_id 10, a
-- flat on/off cooldown distinct from "Rune Enchantment" itself (id 357,
-- recast_id 92, the menu wrapper with no cooldown of its own). It's a
-- single non-stacking cooldown, so the live value can be read directly
-- each render with no client-side ledger needed.
--
-- The duration isn't hardcoded since it varies with gear/JP; it's learned
-- from the live value instead - run_recast_full is captured the moment a
-- fresh use is detected (remaining jumping up from a lower value).
local RUN_RUNE_RECAST_ID  = 10
local RUN_RECAST_FALLBACK = 5  -- best guess before any use is observed this session

local RUN_TABLET_W, RUN_TABLET_H = 56, 56   -- was 24x24 - too small to read in-game
-- Glyphs render at the SAME size/position as a 56×56 tile slot, not a
-- smaller inset icon: the arch art's sockets were carved at this exact
-- tile size/spacing (see images/other/runes/rune_arch.png's generator),
-- so a glyph centered on a tile lands dead-center in its socket.
--
-- All 3 slots use the same plain glyph art now - no per-slot _left/_right
-- variant. An earlier version leaned the outer two glyphs inward to match
-- the socket's tilt, but that meant 16 extra rotated files the renderer
-- depended on; a missing/bad one is exactly what showed up in-game as a
-- plain white square in the left socket (Windower's fallback for a
-- texture that failed to load). Not worth the fragility for a subtle tilt.
local RUN_TABLET_GAP   = 20   -- was 9 - scaled with the tablets so spacing stays proportional
local RUN_TABLET_SPACE = RUN_TABLET_W + RUN_TABLET_GAP
local RUN_ARCH_DY      = 32   -- was 10 - how much higher the centre slot sits
local RUN_ROW_GAP      = 16   -- was 9 - gap between the arch and the ring below

-- True 5-segment donut ring (ring_seg1.png..ring_seg5.png), replacing the
-- old 10-dot-pip placeholder. Each segment file is a full-diameter canvas
-- with one pre-rotated wedge baked in (this codebase never rotates images
-- at runtime - see the pre-rotated COR cards and the hotbar's cooldown
-- sweep frame sequence - so all 5 stack at the SAME on-screen position to
-- compose the complete ring, rather than each needing its own x/y like the
-- old dots did).
local RUN_RING_SEGMENTS = 5
local RUN_RING_SIZE     = 80   -- ring_seg*.png native size (square canvas)
local RUN_RING_COLOR    = {r=70, g=140, b=230}

local RUN_W       = 3*RUN_TABLET_W + 2*RUN_TABLET_GAP
local RUN_RING_CX = RUN_W / 2
local RUN_RING_CY = (RUN_TABLET_H + RUN_ARCH_DY) + RUN_ROW_GAP + RUN_RING_SIZE/2

-- The arch art is now a full Romanesque archway - the band sweeps all the
-- way down to a vertical tangent on each side (a true circular arc through
-- the 3 sockets, extended to 90°), then continues as a short straight
-- pillar stub carrying a carved relief panel and a glowing diamond-chain
-- inlay (see the generator for the geometry). Because the curve bulges out
-- further than the old shallow-dome version, the art's bounding box isn't
-- centred the same way on each axis - these offsets come straight out of
-- the generator's computed origin, not a hand-picked margin.
local RUN_ARCH_OFFSET_X = 41.25   -- art's left edge, left of the tile anchor
local RUN_ARCH_OFFSET_Y = 11.0    -- art's top edge, above the tile anchor
local RUN_ARCH_W = 290.5
local RUN_ARCH_H = 314.25

-- The pillars now run far enough down that the arch image's own bounding
-- box already covers the recast ring beneath it - no extra height needed
-- in the panel's drag hitbox for the ring the way the old shallow dome
-- required. Panel x/y is the art's top-left.
local RUN_PANEL_W = RUN_ARCH_W
local RUN_PANEL_H = RUN_ARCH_H

local function run_tile_anchor(panel_x, panel_y)
  return panel_x + RUN_ARCH_OFFSET_X, panel_y + RUN_ARCH_OFFSET_Y
end

local function make_arch_bg(x, y)
  local img = images.new({draggable=false, texture={fit=false}}, true)
  img:path(windower.addon_path .. '/images/other/runes/rune_arch.png')
  img:fit(false); img:size(RUN_ARCH_W, RUN_ARCH_H); img:pos(x, y)
  img:color(255, 255, 255); img:alpha(255); img:hide()
  return img
end

local function make_glyph(x, y)
  local img = images.new({draggable=false, texture={fit=false}}, true)
  img:path(windower.addon_path .. '/images/other/runes/glyph_ignis.png')
  img:fit(false); img:size(RUN_TABLET_W, RUN_TABLET_H); img:pos(x, y)
  img:color(255, 255, 255); img:hide()
  return img
end

local function make_ring_segment(n)
  local img = images.new({draggable=false, texture={fit=false}}, true)
  img:path(windower.addon_path .. '/images/other/runes/ring_seg' .. n .. '.png')
  img:fit(false); img:size(RUN_RING_SIZE, RUN_RING_SIZE); img:hide()
  return img
end

-- Every wedge shares the same bounding-box position - the wedge shape
-- itself (pre-rotated into the image) is what puts it at the right spot
-- around the ring, not an x/y offset.
local function run_ring_pos(bx, by)
  local cx, cy = bx + RUN_RING_CX, by + RUN_RING_CY
  return cx - RUN_RING_SIZE/2, cy - RUN_RING_SIZE/2
end

-- Slots 1 (left) and 3 (right) sit RUN_ARCH_DY lower than slot 2 (centre),
-- giving the row a shallow arch instead of a flat line.
local function run_tablet_pos(slot, bx, by)
  local x = bx + (slot-1) * RUN_TABLET_SPACE
  local y = by + (slot == 2 and 0 or RUN_ARCH_DY)
  return x, y
end


-- Tracked at module scope for the same reason as SCH's sch_used/sch_next_regen:
-- reload_hotbar() can recreate this panel, and module scope survives that.
local run_recast_full    = RUN_RECAST_FALLBACK
local run_prev_remaining = 0

local function create_run_panel(x, y)
  local panel = utility_panel:new(x, y, RUN_PANEL_W, RUN_PANEL_H)
  panel.content_draggable = true

  panel.arch_bg = make_arch_bg(x, y)
  panel.glyphs, panel.ring = {}, {}
  local bx, by = run_tile_anchor(x, y)
  for slot = 1, RUN_N do
    local tx, ty = run_tablet_pos(slot, bx, by)
    panel.glyphs[slot] = make_glyph(tx, ty)
  end
  for i = 1, RUN_RING_SEGMENTS do
    panel.ring[i] = make_ring_segment(i)
  end
  do
    local rx, ry = run_ring_pos(bx, by)
    for i = 1, RUN_RING_SEGMENTS do panel.ring[i]:pos(rx, ry) end
  end

  panel.on_position_changed = function(p, nx, ny)
    p.arch_bg:pos(nx, ny)
    local nbx, nby = run_tile_anchor(nx, ny)
    for slot = 1, RUN_N do
      local tx, ty = run_tablet_pos(slot, nbx, nby)
      p.glyphs[slot]:pos(tx, ty)
    end
    local rx, ry = run_ring_pos(nbx, nby)
    for i = 1, RUN_RING_SEGMENTS do
      p.ring[i]:pos(rx, ry)
    end
  end

  local function run_hide_all(p)
    p.arch_bg:hide()
    for _, g in ipairs(p.glyphs)  do g:hide() end
    for _, s in ipairs(p.ring)    do s:hide() end
  end
  panel.on_show    = function(p) p:render() end
  panel.on_hide     = run_hide_all
  panel.on_destroy  = run_hide_all

  function panel:render()
    if not self.visible then return end
    local pd = windower.ffxi.get_player()
    if not pd then return end

    local active = {}
    for _, b in ipairs(pd.buffs or {}) do
      if RUNE_GLYPH[b] and #active < RUN_N then table.insert(active, b) end
    end

    self.arch_bg:show()
    for slot = 1, RUN_N do
      local buff = active[slot]
      if buff then
        self.glyphs[slot]:path(windower.addon_path .. '/images/other/runes/glyph_' .. RUNE_GLYPH[buff] .. '.png')
        self.glyphs[slot]:show()
      else
        self.glyphs[slot]:hide()
      end
    end

    -- Ring fills clockwise from the top as the recast elapses; full ring
    -- means ready to swap, matching the SCH/COR/DNC pip gauges' convention.
    local recasts   = windower.ffxi.get_ability_recasts()
    local remaining = (recasts and recasts[RUN_RUNE_RECAST_ID] or 0) / 60
    if remaining > run_prev_remaining + 0.05 then
      -- Remaining jumped up from a lower value: a fresh use just started,
      -- and the observed value is the true current duration.
      run_recast_full = remaining
    end
    run_prev_remaining = remaining
    local frac = run_recast_full > 0
      and math.max(0, math.min(1, (run_recast_full - remaining) / run_recast_full))
      or 1
    local lit = math.floor(RUN_RING_SEGMENTS * frac + 0.0001)
    for i = 1, RUN_RING_SEGMENTS do
      if i <= lit then
        self.ring[i]:color(RUN_RING_COLOR.r, RUN_RING_COLOR.g, RUN_RING_COLOR.b); self.ring[i]:alpha(255)
      else
        self.ring[i]:color(35, 35, 35); self.ring[i]:alpha(110)
      end
      self.ring[i]:show()
    end
  end

  return panel
end

-- ── Active panel handles ─────────────────────────────────────────────────────
local dnc_panel, sch_panel, cor_panel, run_panel

-- Polls both gauges a few times a second so time-based state (SCH charge
-- regen, RUN recast ring) updates continuously rather than only on
-- discrete events like an ability use or buff change.
local gauge_refresh_frame = 0
windower.register_event('prerender', function()
  -- Dagger slide-in animation (runs every frame until complete)
  if sch_dagger_panel and sch_dagger_panel.dagger and sch_dagger_anim_frame < SCH_DAGGER_ANIM_TOTAL then
    sch_dagger_anim_frame = sch_dagger_anim_frame + 1
    local t    = sch_dagger_anim_frame / SCH_DAGGER_ANIM_TOTAL
    local ease = t * t * (3 - 2 * t)
    sch_dagger_panel.dagger:pos(sch_dagger_panel.x,
      math.floor(sch_dagger_panel.y - SCH_DAGGER_SLIDE_PX * (1 - ease)))
  end
  -- Periodic state refresh (every 15 frames)
  if not sch_panel and not sch_sym_panel and not sch_dagger_panel and not sch_sublim_panel and not run_panel then return end
  gauge_refresh_frame = gauge_refresh_frame + 1
  if gauge_refresh_frame % 15 == 0 then
    if sch_panel then sch_panel:render() end
    if run_panel then run_panel:render() end
  end
end)



-- ── Public API ───────────────────────────────────────────────────────────────
function utility_gauges:teardown()
  if dnc_panel then dnc_panel:destroy(); dnc_panel = nil end
  if sch_panel then sch_panel:destroy(); sch_panel = nil end
  if sch_sym_panel then sch_sym_panel:destroy(); sch_sym_panel = nil end
  if sch_dagger_panel then sch_dagger_panel:destroy(); sch_dagger_panel = nil end
  if sch_sublim_panel then sch_sublim_panel:destroy(); sch_sublim_panel = nil end
  if cor_panel then cor_panel:destroy(); cor_panel = nil end
  if run_panel then run_panel:destroy(); run_panel = nil end
end

function utility_gauges:setup(player_obj, settings, default_x, default_y)
  self:teardown()
  local gset  = settings.Utility and settings.Utility.Gauges or {}
  local next_y = default_y

  local function resolve_pos(key, panel_h)
    local s = gset[key] or {}
    local ox, oy = s.OffsetX or 0, s.OffsetY or 0
    if ox == 0 and oy == 0 then
      local ax, ay = default_x, next_y
      next_y = next_y + panel_h + 14
      return ax, ay
    end
    return ox, oy
  end

  if has_job(player_obj, JOB_DNC) then
    local x, y = resolve_pos('DNC', PIP_H)
    dnc_panel = create_dnc_panel(x, y)
    dnc_panel:render(player_obj.finishing_moves or 0)
  end

  -- SCH visibility state
  local _av = settings and settings.Accessibility or {}
  sch_a11y_mode = SCH_PALETTE[_av.ColorblindMode or ''] and _av.ColorblindMode or 'off'
  local _sv = settings and settings.Utility and settings.Utility.SCHGauge or {}
  sch_show_gauge  = _sv.Show       ~= false
  sch_show_gems   = _sv.ShowGems   ~= false
  sch_show_strats = _sv.ShowStrats ~= false
  sch_show_sublim = _sv.ShowSublim ~= false
  sch_show_dagger = _sv.ShowDagger ~= false

  if has_job(player_obj, JOB_SCH) then
    local x, y = resolve_pos('SCH', SCH_GAUGE_H)
    local _ok, _res = pcall(create_sch_panel, x, y)
    if _ok then
      sch_panel = _res
      local _rok, _rerr = pcall(function() sch_panel:render() end)
      if not _rok then
        windower.add_to_chat(167, '[SCH] render() error: ' .. tostring(_rerr))
      end
    else
      windower.add_to_chat(167, '[SCH] create_sch_panel error: ' .. tostring(_res))
    end
    -- stored independent positions (restored on unfuse)
    local _sdv=gset['SCHDagger'] or {}; sch_dagger_ind_x,sch_dagger_ind_y=_sdv.OffsetX or 0,_sdv.OffsetY or 0
    local _slv=gset['SCHSublim'] or {}; sch_sublim_ind_x,sch_sublim_ind_y=_slv.OffsetX or 0,_slv.OffsetY or 0
    local _ssv=gset['SCHSyms']   or {}; sch_sym_ind_x,   sch_sym_ind_y   =_ssv.OffsetX or 0,_ssv.OffsetY or 0
    -- start fused; unfuse now if gems were saved as hidden
    local _fdx,_fdy,_fsx,_fsy,_fslx,_fsly = sch_fuse_positions(x, y)
    sch_dagger_panel = create_sch_dagger_panel(_fdx, _fdy);  sch_dagger_panel:render()
    sch_sublim_panel = create_sch_sublim_panel(_fslx,_fsly); sch_sublim_panel:render()
    sch_sym_panel    = create_sch_sym_panel(_fsx, _fsy);     sch_sym_panel:render()
    sch_fused = true
    if not sch_show_gems then sch_apply_unfuse() end
  end

  if has_job(player_obj, JOB_COR) then
    local x, y = resolve_pos('COR', COR_PANEL_H)
    cor_panel = create_cor_panel(x, y)
    cor_panel:scan_roll_buff()
  end

  if has_job(player_obj, JOB_RUN) then
    local x, y = resolve_pos('RUN', PIP_H)
    run_panel = create_run_panel(x, y)
    run_panel:render()
  end
end

function utility_gauges:update_all(player_obj)
  if dnc_panel then dnc_panel:render(player_obj.finishing_moves) end
  if sch_panel then sch_panel:render() end
  if sch_sym_panel then sch_sym_panel:render() end
  if sch_dagger_panel then sch_dagger_panel:render() end
  if sch_sublim_panel then sch_sublim_panel:render() end
  if cor_panel then cor_panel:scan_roll_buff() end
  if run_panel then run_panel:render() end
end

function utility_gauges:set_colorblind_mode(mode)
  sch_a11y_mode = SCH_PALETTE[mode] and mode or 'off'
  if sch_dagger_panel then sch_dagger_panel:render() end
  if sch_sublim_panel then sch_sublim_panel:render() end
  return sch_a11y_mode
end

function utility_gauges:toggle_sch(flag, settings_ref)
  if flag == 'gauge' then
    sch_show_gauge = not sch_show_gauge
    if sch_panel then sch_panel:render() end
    if sch_sym_panel    then if sch_show_gauge then sch_sym_panel:show()    else sch_sym_panel:hide()    end end
    if sch_dagger_panel then if sch_show_gauge then sch_dagger_panel:show()  else sch_dagger_panel:hide()  end end
    if sch_sublim_panel then if sch_show_gauge then sch_sublim_panel:show()  else sch_sublim_panel:hide()  end end
    return sch_show_gauge
  elseif flag == 'gems' then
    sch_show_gems = not sch_show_gems
    if sch_panel then sch_panel:render() end
    if sch_show_gems then
      -- fuse: lock sub-panels onto gem-gauge-relative positions
      sch_fused = true
      if sch_panel then sch_apply_fuse(sch_panel.x, sch_panel.y) end
      self:set_edit_mode(sch_edit_active)
    else
      -- unfuse: restore sub-panels to their last independent positions
      sch_apply_unfuse()
    end
    return sch_show_gems
  elseif flag == 'strats' then
    sch_show_strats = not sch_show_strats
    if sch_sym_panel then sch_sym_panel:render() end
    self:set_edit_mode(sch_edit_active)
    return sch_show_strats
  elseif flag == 'sublim' then
    sch_show_sublim = not sch_show_sublim
    if sch_sublim_panel then sch_sublim_panel:render() end
    self:set_edit_mode(sch_edit_active)
    return sch_show_sublim
  elseif flag == 'dagger' then
    sch_show_dagger = not sch_show_dagger
    if sch_dagger_panel then sch_dagger_panel:render() end
    self:set_edit_mode(sch_edit_active)
    return sch_show_dagger
  end
end

function utility_gauges:save_sch_visibility(settings_ref)
  settings_ref.Utility             = settings_ref.Utility or {}
  settings_ref.Utility.SCHGauge   = settings_ref.Utility.SCHGauge or {}
  settings_ref.Utility.SCHGauge.Show       = sch_show_gauge
  settings_ref.Utility.SCHGauge.ShowGems   = sch_show_gems
  settings_ref.Utility.SCHGauge.ShowStrats = sch_show_strats
  settings_ref.Utility.SCHGauge.ShowSublim = sch_show_sublim
  settings_ref.Utility.SCHGauge.ShowDagger = sch_show_dagger
end

function utility_gauges:on_action(act)
  if not act or not act.actor_id then return end
  local pid = windower.ffxi.get_player()
  if not pid or act.actor_id ~= pid.id then return end

  if sch_panel and act.category == 6 and act.param then
    -- charge tracking only; symbol display reads pd.buffs in render()
    local ab = resources.job_abilities[act.param]
    if ab and ab.recast_id == SCH_STRAT_RECAST_ID then
      sch_panel:note_charge_used()
    end
  end

  if cor_panel and act.category == 6 and act.targets then
    -- msg 420 = new roll, 424 = double-up
    -- act.param is the ability ID; COR_ROLL_PARAMS maps it to a buff_id
    -- (not uniform +212 - that formula breaks for several rolls)
    local roll_result, is_doubleup
    for _, tgt in ipairs(act.targets) do
      if tgt.actions then
        for _, a in ipairs(tgt.actions) do
          if a.message == 420 or a.message == 424 then
            roll_result  = a.param
            is_doubleup  = (a.message == 424)
            break
          end
        end
      end
      if roll_result then break end
    end

    if roll_result and roll_result >= 1 and roll_result <= 11 then
      local buff_id = COR_ROLL_PARAMS[act.param]
      if buff_id then
        cor_panel:apply_roll(buff_id, roll_result, is_doubleup)
      end
    end
  end
end

function utility_gauges:handle_mouse(ev_type, x, y)
  -- Explicit guards mirror how the lock panel is called.  DO NOT use
  -- ipairs({dnc_panel, ...}) - ipairs stops at the first nil, so any panel
  -- after a missing job gauge would be silently skipped.
  if dnc_panel and dnc_panel:on_mouse(ev_type, x, y) ~= nil then return true end
  if sch_panel and sch_panel:on_mouse(ev_type, x, y) ~= nil then return true end
  if not sch_fused and sch_show_gauge then
    if sch_sym_panel    and sch_show_strats  and sch_sym_panel:on_mouse(ev_type,x,y)    ~= nil then return true end
    if sch_dagger_panel and sch_show_dagger  and sch_dagger_panel:on_mouse(ev_type,x,y) ~= nil then return true end
    if sch_sublim_panel and sch_show_sublim  and sch_sublim_panel:on_mouse(ev_type,x,y) ~= nil then return true end
  end
  if cor_panel and cor_panel:on_mouse(ev_type, x, y) ~= nil then return true end
  if run_panel and run_panel:on_mouse(ev_type, x, y) ~= nil then return true end
  return false
end

function utility_gauges:on_buff_change()
  if sch_panel then sch_panel:render() end
  if sch_sym_panel then sch_sym_panel:render() end
  if sch_dagger_panel then sch_dagger_panel:render() end
  if sch_sublim_panel then sch_sublim_panel:render() end
  if cor_panel then cor_panel:scan_roll_buff() end
  if run_panel then run_panel:render() end
end

function utility_gauges:set_edit_mode(active)
  sch_edit_active = active
  if dnc_panel then dnc_panel:set_edit_mode(active) end
  -- gem panel: grip only when gauge background is visible
  if sch_panel then sch_panel:set_edit_mode(active and sch_show_gems and sch_show_gauge) end
  -- sub-panels: grip only when unfused and their element is shown
  local sub = active and not sch_fused and sch_show_gauge
  if sch_sym_panel    then sch_sym_panel:set_edit_mode(sub and sch_show_strats)    end
  if sch_dagger_panel then sch_dagger_panel:set_edit_mode(sub and sch_show_dagger)  end
  if sch_sublim_panel then sch_sublim_panel:set_edit_mode(sub and sch_show_sublim)  end
  if cor_panel then cor_panel:set_edit_mode(active) end
  if run_panel then run_panel:set_edit_mode(active) end
end

function utility_gauges:hide_all()
  if dnc_panel then dnc_panel:hide() end
  if sch_panel then sch_panel:hide() end
  if sch_sym_panel then sch_sym_panel:hide() end
  if sch_dagger_panel then sch_dagger_panel:hide() end
  if sch_sublim_panel then sch_sublim_panel:hide() end
  if cor_panel then cor_panel:hide() end
  if run_panel then run_panel:hide() end
end

function utility_gauges:show_all()
  if dnc_panel then dnc_panel:show() end
  if sch_panel then sch_panel:show() end
  if sch_sym_panel then sch_sym_panel:show() end
  if sch_dagger_panel then sch_dagger_panel:show() end
  if sch_sublim_panel then sch_sublim_panel:show() end
  if cor_panel then cor_panel:show() end
  if run_panel then run_panel:show() end
end

function utility_gauges:save_positions(settings)
  if not settings.Utility then return end
  local g = settings.Utility.Gauges
  if not g then return end
  local function save(panel, key)
    if panel and g[key] then g[key].OffsetX = panel.x; g[key].OffsetY = panel.y end
  end
  save(dnc_panel,'DNC'); save(sch_panel,'SCH')
  if not sch_fused then
    save(sch_sym_panel,'SCHSyms');      if sch_sym_panel    then sch_sym_ind_x,    sch_sym_ind_y    = sch_sym_panel.x,    sch_sym_panel.y    end
    save(sch_dagger_panel,'SCHDagger'); if sch_dagger_panel then sch_dagger_ind_x, sch_dagger_ind_y = sch_dagger_panel.x, sch_dagger_panel.y end
    save(sch_sublim_panel,'SCHSublim'); if sch_sublim_panel then sch_sublim_ind_x, sch_sublim_ind_y = sch_sublim_panel.x, sch_sublim_panel.y end
  end
  save(cor_panel,'COR'); save(run_panel,'RUN')
end

return utility_gauges