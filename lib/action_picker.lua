--[[
  lib/action_picker.lua  (v5 — refactored generic filter strips + AoE scope filter)

  Five-tab panel:
    Magic   → Type → School → Scope (AoE/Single/Self)
    Trusts  → Role
    Ability → Scope
    WSkills → Physical/Magical → Scope
    Cfg     → Settings editor

  Filter strips are fully generic: TAB_FILTER_CHAIN drives which dimensions
  appear per tab. Each strip only renders if ≥2 distinct values are present.

  on_mouse() → 'consumed' | 'dragging' | action_table | nil
]]

local action_picker = {}

-- Debug logging: gated on //htb debug (ui.theme.dev_mode). ui is a global
-- (required without 'local' in xivhotbar2.lua) so it's visible here too.
local function dbg(msg)
  if ui and ui.theme and ui.theme.dev_mode then
    log('[AP] ' .. msg)
  end
end

-- ── Constants ─────────────────────────────────────────────────────────────
local ICON_SIZE     = 40   -- set from theme in init()
local ICON_GAP      = 4
local GRID_COLS     = 6
local GRID_ROWS     = 6
local PANEL_PAD     = 8
local HEADER_H      = 30  -- two-line header: title + drag hint
local TAB_H         = 26  -- slightly taller than before for easier clicking
local STRIP_H       = 22
local NAME_H        = 18
local SCROLL_H      = 26
local MAX_STRIPS    = 3
local MAX_STRIP_OPT = 14
-- Settings tab
local MAX_ST_ROWS   = 11
local ST_ROW_H      = 22
local ST_BOOL_A     = -98
local ST_BOOL_C     = -48
local ST_NUM_A      = -72
local ST_NUM_B      = -48
local ST_NUM_C      = -18
local ST_CYC_PREV   = -100  -- [<] for cycle rows
local ST_CYC_MID    =  -86  -- value label for cycle rows (68 px before [>])
local ST_CYC_NEXT   =  -18  -- [>] for cycle rows

-- ── Appearance themes ──────────────────────────────────────────────────────
-- All solid-colour themes use white-square.png as base and :color(r,g,b) tint.
-- Wallpaper themes load a user-supplied PNG from images/backgrounds/.
-- fr/fg/fb are the foreground (text) colour that reads best against that bg.
local PANEL_THEMES = {
  {key='dark',      label='Dark',       path=nil,                    r=15,  g=18,  b=25,  a=230, fr=255, fg=255, fb=255},
  {key='blue',      label='Blue',       path=nil,                    r=18,  g=40,  b=98,  a=215, fr=210, fg=230, fb=255},
  {key='skyblue',   label='Sky Blue',   path=nil,                    r=55,  g=100, b=180, a=205, fr=255, fg=255, fb=255},
  {key='purple',    label='Purple',     path=nil,                    r=68,  g=15,  b=98,  a=215, fr=230, fg=210, fb=255},
  {key='yellow',    label='Yellow',     path=nil,                    r=195, g=165, b=12,  a=210, fr=22,  fg=18,  fb=5 },
  {key='pine',      label='Pine',       path=nil,                    r=12,  g=68,  b=28,  a=215, fr=210, fg=255, fb=220},
  {key='red',       label='Red',        path=nil,                    r=118, g=12,  b=12,  a=215, fr=255, fg=215, fb=210},
  {key='orange',    label='Orange',     path=nil,                    r=158, g=65,  b=8,   a=215, fr=255, fg=238, fb=210},
  -- PlayOnline wallpapers — place CONVERTED standard PNGs in images/backgrounds/.
  -- The POL container is a proprietary SE format; see WALLPAPERS.txt for instructions.
  -- FFXI wallpapers
  {key='xi_box_art',    label='XI: Box',      path='backgrounds/xi_box_art',    r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_cg_art',     label='XI: CG Art',   path='backgrounds/xi_cg_art',     r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_logo',       label='XI: Logo',     path='backgrounds/xi_logo',       r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_roz',        label='XI: RoZ',      path='backgrounds/xi_roz',        r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_elvaan_1',   label='XI: Elvaan1',  path='backgrounds/xi_elvaan_1',   r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_elvaan_2',   label='XI: Elvaan2',  path='backgrounds/xi_elvaan_2',   r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_galka',      label='XI: Galka',    path='backgrounds/xi_galka',      r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_hume_1',     label='XI: Hume 1',   path='backgrounds/xi_hume_1',     r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_hume_2',     label='XI: Hume 2',   path='backgrounds/xi_hume_2',     r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_mithra',     label='XI: Mithra',   path='backgrounds/xi_mithra',     r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_tarutaru_1', label='XI: Taru 1',   path='backgrounds/xi_tarutaru_1', r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_tarutaru_2', label='XI: Taru 2',   path='backgrounds/xi_tarutaru_2', r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_image_1',    label='XI: Image 1',  path='backgrounds/xi_image_1',    r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_image_2',    label='XI: Image 2',  path='backgrounds/xi_image_2',    r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_image_3',    label='XI: Image 3',  path='backgrounds/xi_image_3',    r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_image_4',    label='XI: Image 4',  path='backgrounds/xi_image_4',    r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_image_5',    label='XI: Image 5',  path='backgrounds/xi_image_5',    r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_op_1',       label='XI: Open. 1',  path='backgrounds/xi_opening_1',  r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_op_2',       label='XI: Open. 2',  path='backgrounds/xi_opening_2',  r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_op_3',       label='XI: Open. 3',  path='backgrounds/xi_opening_3',  r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_op_4',       label='XI: Open. 4',  path='backgrounds/xi_opening_4',  r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_op_5',       label='XI: Open. 5',  path='backgrounds/xi_opening_5',  r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_op_6',       label='XI: Open. 6',  path='backgrounds/xi_opening_6',  r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_op_7',       label='XI: Open. 7',  path='backgrounds/xi_opening_7',  r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_op_8',       label='XI: Open. 8',  path='backgrounds/xi_opening_8',  r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_op_9',       label='XI: Open. 9',  path='backgrounds/xi_opening_9',  r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='xi_op_10',      label='XI: Open.10',  path='backgrounds/xi_opening_10', r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  -- Other Square Enix wallpapers
  {key='chocobo_1',     label='Chocobo 1',    path='backgrounds/chocobo_1',     r=255,g=255,b=255,a=180,fr=22, fg=14, fb=5 },
  {key='chocobo_2',     label='Chocobo 2',    path='backgrounds/chocobo_2',     r=255,g=255,b=255,a=180,fr=22, fg=14, fb=5 },
  {key='chocobo_3',     label='Chocobo 3',    path='backgrounds/chocobo_3',     r=255,g=255,b=255,a=180,fr=22, fg=14, fb=5 },
  {key='ffvii_ac_1',    label='AC: 1',        path='backgrounds/ffvii_ac_1',    r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='ffvii_ac_2',    label='AC: 2',        path='backgrounds/ffvii_ac_2',    r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='ffvii_ac_3',    label='AC: 3',        path='backgrounds/ffvii_ac_3',    r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='ffvii_ac_4',    label='AC: 4',        path='backgrounds/ffvii_ac_4',    r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='ffvii_ac_5',    label='AC: 5',        path='backgrounds/ffvii_ac_5',    r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='ffvii_ac_6',    label='AC: 6',        path='backgrounds/ffvii_ac_6',    r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='ffxii_ashe',    label='XII: Ashe',    path='backgrounds/ffxii_ashe',    r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='ffxii_balflear',label='XII: Balfl.',  path='backgrounds/ffxii_balflear',r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='ffxii_basch',   label='XII: Basch',   path='backgrounds/ffxii_basch',   r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='ffxii_fran',    label='XII: Fran',    path='backgrounds/ffxii_fran',    r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='ffxii_penelo',  label='XII: Penelo',  path='backgrounds/ffxii_penelo',  r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='ffxii_vaan',    label='XII: Vaan',    path='backgrounds/ffxii_vaan',    r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='ffxc_1',        label='CrysChron 1',  path='backgrounds/ffxc_1',        r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
  {key='ffxc_2',        label='CrysChron 2',  path='backgrounds/ffxc_2',        r=255,g=255,b=255,a=180,fr=255,fg=255,fb=255},
}

-- Hotbar backdrops: simpler list (no text colour, wallpapers intentionally omitted
-- since per-bar wallpaper stretching looks inconsistent).
local HOTBAR_THEMES = {
  {key='none',    label='None',     r=0,   g=0,   b=0,   a=0  },
  {key='dark',    label='Dark',     r=15,  g=18,  b=25,  a=165},
  {key='blue',    label='Blue',     r=18,  g=40,  b=98,  a=145},
  {key='skyblue', label='Sky Blue', r=55,  g=100, b=180, a=135},
  {key='purple',  label='Purple',   r=68,  g=15,  b=98,  a=145},
  {key='yellow',  label='Yellow',   r=195, g=165, b=12,  a=135},
  {key='pine',    label='Pine',     r=12,  g=68,  b=28,  a=145},
  {key='red',     label='Red',      r=118, g=12,  b=12,  a=145},
  {key='orange',  label='Orange',   r=158, g=65,  b=8,   a=145},
}

local PANEL_FONTS = {
  {key='Calibri',         label='Calibri'  },
  {key='Segoe UI',        label='Segoe UI' },
  {key='Trebuchet MS',    label='Trebuchet'},
  {key='Arial',           label='Arial'    },
  {key='Verdana',         label='Verdana'  },
  {key='Tahoma',          label='Tahoma'   },
  {key='Times New Roman', label='Times NR' },
}

-- ── Data tables ───────────────────────────────────────────────────────────
local SKILL_NAMES = {
  [32]='Divine Magic',    [33]='Healing Magic',        [34]='Enhancing Magic',
  [35]='Enfeebling Magic',[36]='Elemental Magic',      [37]='Dark Magic',
  [38]='Summoning Magic', [39]='Ninjutsu',              [40]='Singing',
  [41]='Stringed Instrument',[42]='Wind Instrument',   [43]='Blue Magic',
  [44]='Geomancy',        [45]='Handbell',
}

local SCHOOL_ORDER = {
  {key='Divine Magic',        label='Divn.'  },
  {key='Healing Magic',       label='Heal.'  },
  {key='Enhancing Magic',     label='Enha.'  },
  {key='Enfeebling Magic',    label='Enfe.'  },
  {key='Elemental Magic',     label='Elem.'  },
  {key='Dark Magic',          label='Dark.'  },
  {key='Summoning Magic',     label='Summ.'  },
  {key='Ninjutsu',            label='Ninj.'  },
  {key='Singing',             label='Sing.'  },
  {key='Stringed Instrument', label='Str.'   },
  {key='Wind Instrument',     label='Wind.'  },
  {key='Blue Magic',          label='Blue.'  },
  {key='Geomancy',            label='Geo.'   },
  {key='Handbell',            label='Bell.'  },
}

local SPELL_TYPE_DEFS = {
  {key='WhiteMagic', label='White.' },
  {key='BlackMagic', label='Black.' },
  {key='DarkMagic',  label='Dark.'  },
  {key='BlueMagic',  label='Blue.'  },
  {key='Ninjutsu',   label='Ninja.' },
  {key='Summoning',  label='Summ.'  },
  {key='Geomancy',   label='Geo.'   },
}

local TRUST_ROLES = {
  ['valaineral']='Tank',          ['curilla']='Tank',
  ['iron eater']='Tank',          ['naja salaheem']='Tank',
  ['mnejing']='Tank',             ['zeid ii']='Tank',
  ['leonoyne']='Tank',            ['rughadjeen']='Tank',
  ['rongelouts n distaud']='Tank',['volker']='Tank',
  ['gessho']='Tank',              ['mayakov']='Tank',
  ['amchuchu']='Tank',            ['klara']='Tank',
  ['prishe ii']='Tank',           ['balamor']='Tank',
  ['apururu']='Healer',           ['apururu (uc)']='Healer',
  ['kupipi']='Healer',            ['yoran-oran']='Healer',
  ['yoran-oran (u.)']='Healer',   ['yoran-oran (uc)']='Healer',
  ['mihli aliapoh']='Healer',     ['areuhat']='Healer',
  ['cherukiki']='Healer',         ['sakura']='Healer',
  ['luquy']='Healer',             ["selh'teus"]='Healer',
  ['koru-moru']='Healer',         ['domina shantotto']='Healer',
  ['ferrous coffin']='Healer',    ['monberaux']='Healer',
  ['nashmeira ii']='Healer',      ['arciela ii']='Healer',
  ['ulmia']='Support',            ['ovjang']='Support',
  ['joachim']='Support',          ['najelith']='Support',
  ['august']='Support',           ['rainemard']='Support',
  ['qultada']='Support',          ['lhu mhakaracca']='Support',
  ['lion']='Support',             ['briaris']='Support',
  ['king of hearts']='Support',   ['karaha-baruha']='Support',
  ['arciela']='Support',
  ['shantotto']='Caster',         ['shantotto ii']='Caster',
  ['ullegore']='Caster',          ['ingrid']='Caster',
  ['kayeel-payeel']='Caster',     ['gadalar']='Caster',
  ['lion ii']='Caster',
  ['tenzen']='Melee',             ['tenzen ii']='Melee',
  ['gilgamesh']='Melee',          ['zeid']='Melee',
  ['prishe']='Melee',             ['ayame']='Melee',
  ['iroha']='Melee',              ['iroha ii']='Melee',
  ['laila']='Melee',              ['darrcuiln']='Melee',
  ['zazarg']='Melee',             ['nashmeira']='Melee',
  ['ark angel hm']='Melee',       ['ark angel ef']='Melee',
  ['ark angel gg']='Melee',       ['ark angel mr']='Melee',
  ['ark angel tg']='Melee',       ['lilisette']='Melee',
  ['lilisette ii']='Melee',       ['excenmille']='Melee',
  ['maat']='Melee',               ['margret']='Melee',
  ['aldo']='Melee',               ['naji']='Melee',
  ['rosulatia']='Melee',          ['lehko habhoka']='Melee',
  ['shikaree z']='Ranged',        ['semih lafihna']='Ranged',
}

local TRUST_ROLE_ORDER = {
  {key='Tank',    label='Tank'},
  {key='Healer',  label='Heal'},
  {key='Support', label='Supp'},
  {key='Caster',  label='Cast'},
  {key='Melee',   label='Mlee'},
  {key='Ranged',  label='Rng.'},
  {key='Other',   label='Othr'},
}

local WS_TYPE_ORDER = {
  {key='Physical', label='Physical'},
  {key='Magical',  label='Magical' },
}

local SCOPE_ORDER = {
  {key='Single', label='Single'},
  {key='AoE',    label='AoE'   },
  {key='Self',   label='Self'  },
}

local CATEGORIES = {
  {key='ma', label='Magic'  },
  {key='tr', label='Trusts' },
  {key='ja', label='Ability'},
  {key='ws', label='WSkills'},
  {key='st', label='Cfg'    },
}

local BAR_NAMES = {
  'First','Second','Third','Fourth','Fifth',
  'Sixth','Seventh','Eighth','Ninth','Tenth',
}

-- ── Filter builder functions ───────────────────────────────────────────────
-- Each takes the already-filtered action list and returns an opts table
-- ({key,label} pairs) or nil if <2 distinct values exist.

local function build_type_filter(actions)
  local seen = {}
  for _, a in ipairs(actions) do if a.spell_type then seen[a.spell_type] = true end end
  local opts = {{key='all', label='All'}}
  for _, def in ipairs(SPELL_TYPE_DEFS) do
    if seen[def.key] then table.insert(opts, {key=def.key, label=def.label}) end
  end
  return #opts >= 2 and opts or nil
end

local function build_school_filter(actions)
  local seen = {}
  for _, a in ipairs(actions) do if a.spell_school then seen[a.spell_school] = true end end
  local opts = {{key='all', label='All'}}
  for _, def in ipairs(SCHOOL_ORDER) do
    if seen[def.key] then table.insert(opts, {key=def.key, label=def.label}) end
  end
  -- any school not in SCHOOL_ORDER gets a 4-char fallback
  for k in pairs(seen) do
    local found = false
    for _, o in ipairs(opts) do if o.key == k then found = true; break end end
    if not found then table.insert(opts, {key=k, label=k:sub(1,4)}) end
  end
  return #opts >= 2 and opts or nil
end

local function build_role_filter(actions)
  local seen = {}
  for _, a in ipairs(actions) do if a.role then seen[a.role] = true end end
  local opts = {{key='all', label='All'}}
  for _, def in ipairs(TRUST_ROLE_ORDER) do
    if seen[def.key] then table.insert(opts, {key=def.key, label=def.label}) end
  end
  return #opts >= 2 and opts or nil
end

local function build_wstype_filter(actions)
  local seen = {}
  for _, a in ipairs(actions) do if a.ws_type then seen[a.ws_type] = true end end
  local count = 0; for _ in pairs(seen) do count = count + 1 end
  if count < 2 then return nil end
  local opts = {{key='all', label='All'}}
  for _, def in ipairs(WS_TYPE_ORDER) do
    if seen[def.key] then table.insert(opts, {key=def.key, label=def.label}) end
  end
  return opts
end

local function build_scope_filter(actions)
  local seen = {}
  for _, a in ipairs(actions) do if a.scope then seen[a.scope] = true end end
  local count = 0; for _ in pairs(seen) do count = count + 1 end
  if count < 2 then return nil end
  local opts = {{key='all', label='All'}}
  for _, def in ipairs(SCOPE_ORDER) do
    if seen[def.key] then table.insert(opts, {key=def.key, label=def.label}) end
  end
  return #opts >= 2 and opts or nil
end

-- ── Tab filter chains ─────────────────────────────────────────────────────
-- Each entry: {dim=name, build=builder_fn, get=fn(action)->value}
-- Strips are evaluated in order; each strip's options are derived from
-- the action set that already passes all previous strips' active filters.
local TAB_FILTER_CHAIN = {
  ma = {
    {dim='type',   build=build_type_filter,   get=function(a) return a.spell_type  end},
    {dim='school', build=build_school_filter,  get=function(a) return a.spell_school end},
    {dim='scope',  build=build_scope_filter,   get=function(a) return a.scope       end},
  },
  tr = {
    {dim='role',   build=build_role_filter,    get=function(a) return a.role        end},
  },
  ja = {
    {dim='scope',  build=build_scope_filter,   get=function(a) return a.scope       end},
  },
  ws = {
    {dim='wstype', build=build_wstype_filter,  get=function(a) return a.ws_type     end},
    {dim='scope',  build=build_scope_filter,   get=function(a) return a.scope       end},
  },
  st = {},
}

-- ── Helpers ───────────────────────────────────────────────────────────────
local function cell_size() return ICON_SIZE + ICON_GAP end

local function safe_icon(path)
  local f = io.open(path, 'r')
  if f then f:close(); return path end
  return windower.addon_path .. '/images/icons/custom/gear3.png'
end

local function get_spell_school(res)
  if not res.skill then return 'Other' end
  local sid = res.skill
  if resources and resources.skills and resources.skills[sid] then
    return resources.skills[sid].en or SKILL_NAMES[sid] or ('Skill '..sid)
  end
  return SKILL_NAMES[sid] or ('Skill '..tostring(sid))
end

local function get_trust_role(name)
  return TRUST_ROLES[name:lower()] or 'Other'
end

local function get_ws_type(res)
  if res.element and res.element ~= 0 and res.element ~= 'None' and res.element ~= '' then
    return 'Magical'
  end
  return 'Physical'
end

-- Enemy-AoE spells whose targets field lists only Enemy (so the Party/Ally
-- check above won't catch them). Identified by naming convention (-ga/-ja)
-- or explicit lookup for ancient magic and Blue Magic AoE spells.
-- Note: -ra spells that target Enemy DON'T exist for standard player jobs;
-- all player-castable -ra spells (Protectra, Shellra, Barfira…) target
-- Party/Ally and are already handled above. Libra ends in 'ra' but is
-- single-target, which is why -ra is intentionally absent from the suffix check.
local AOE_ENEMY_NAMES = {
  -- Ancient magic tier I (BLM Lv61+)
  quake=true,   tornado=true, flood=true,  freeze=true, burst=true,
  -- Ancient magic tier II (BLM Lv85+, Seekers of Adoulin)
  ['quake ii']=true, ['tornado ii']=true, ['flood ii']=true,
  ['freeze ii']=true,['burst ii']=true,
  -- Ultimate magic
  comet=true, meteor=true,
  -- Blue Magic: enemy-AoE sleep / debuff
  ['sheep song']=true,  ['soporific']=true,     ['stinking gas']=true,
  ['geist wall']=true,  ['magnetite cloud']=true,['cimicine discharge']=true,
  ['cold wave']=true,   ['bad breath']=true,    ['jettatura']=true,
  ['blank gaze']=true,  ['frightful roar']=true, ['sound blast']=true,
  ['lowing']=true,
  -- Blue Magic: enemy-AoE damage
  ['bomb toss']=true,    ['blastbomb']=true,    ['self-destruct']=true,
  ['heat breath']=true,  ['blitzstrahl']=true,
  ['actinic burst']=true,['temporal shift']=true,
  ['whirl of rage']=true,['benthic typhoon']=true,
  ['leafstorm']=true,    ['thunderbolt']=true,
  ['corrosive ooze']=true, ['nectarous deluge']=true,['rending deluge']=true,
  ['embalming earth']=true,['maelstrom']=true,
  ['tearing gust']=true, ['tempestuous upheaval']=true,
  ['searing tempest']=true,['tenebral crush']=true,
  ['spectral flow']=true,['crashing thunder']=true,
  ['entomb']=true,       ['cesspool']=true,     ['sandspin']=true,
  ['1000 needles']=true, ['anvil lightning']=true,['thermal pulse']=true,
}

local function get_scope(res)
  if not res or not res.targets then return 'Single' end
  local t = res.targets
  -- Self-only: no external target selection
  if t.Self and not t.Enemy and not t.Player and not t.Party and not t.Ally then
    return 'Self'
  end
  -- True party/alliance-wide AoE (Curaga, Protectra, Shellra, Barfira, etc.)
  -- Spells that CAN target a specific party member have targets.Player=true;
  -- truly party-wide casts do not.
  if (t.Party or t.Ally) and not t.Player and not t.Enemy then return 'AoE' end
  -- Enemy-targeted AoE: -ga/-ja/-ra suffix spells (Firaga, Blizzaga, Firaja,
  -- and -ra enemy-area spells from Seekers content) plus explicit lookup above.
  if t.Enemy then
    local name = (res.en or ''):lower()
    if name:match('ga$') or name:match('ja$') then return 'AoE' end
    if AOE_ENEMY_NAMES[name] then return 'AoE' end
  end
  return 'Single'
end
local function in_box(x, y, x1, y1, x2, y2)
  return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

-- Text/image factory functions to reduce init() boilerplate
local function make_text(sz, r, g, b, italic)
  local t = texts.new({flags={draggable=false}}, true)
  t:font('Calibri'); t:size(sz)
  t:color(r, g, b); t:alpha(255)
  t:bg_alpha(0); t:bg_visible(false)
  t:stroke_width(2); t:stroke_color(0, 0, 0)
  if italic then t:italic(true) end
  t:text(''); t:hide()
  return t
end

local function make_image(path, w, h, alpha)
  local img = images.new({draggable=false, texture={fit=false}}, true)
  img:fit(false); img:size(w, h)
  img:alpha(alpha); img:path(path)
  img:hide()
  return img
end

-- ── Object pools (module-local) ───────────────────────────────────────────
local database_ref    = nil
local panel_bg        = nil
local title_label     = nil   -- "Action Picker" (larger, prominent)
local hint_label      = nil   -- "drag to reposition" (smaller, italic, grey)
local tab_texts       = {}
local strip_texts     = {}   -- [strip_idx][opt_idx]
local grid_icons      = {}
local name_label      = nil
local scroll_up_btn   = nil
local scroll_down_btn = nil
local drag_icon       = nil
-- Settings tab pools
local st_labels = {}
local st_btn_a  = {}
local st_btn_b  = {}
local st_btn_c  = {}
local st_apply  = nil

-- ── State ─────────────────────────────────────────────────────────────────
action_picker.visible       = false
action_picker.active_cat    = 'ma'
action_picker.strips        = {}   -- array of {dim, get, opts, active}
action_picker.scroll_offset = 0
action_picker.actions       = {ma={}, tr={}, ja={}, ws={}}
action_picker.panel_x       = 0
action_picker.panel_y       = 0
action_picker.panel_w       = 0
action_picker.panel_h       = 0
action_picker.anchor_y      = 0
action_picker.drag          = {active=false, action=nil}
action_picker.panel_drag    = {active=false, last_x=0, last_y=0}
-- Settings tab
action_picker.settings_ref  = nil
action_picker.st_defs       = {}
action_picker.st_scroll     = 0
action_picker.needs_reload  = false

-- ── Layout ────────────────────────────────────────────────────────────────
function action_picker:effective_panel_h()
  local h = PANEL_PAD + HEADER_H + PANEL_PAD
           + TAB_H    + PANEL_PAD
  for _ = 1, #self.strips do h = h + STRIP_H + PANEL_PAD end
  h = h + GRID_ROWS * cell_size() - ICON_GAP + PANEL_PAD
  h = h + NAME_H + PANEL_PAD + SCROLL_H + PANEL_PAD
  return h
end

function action_picker:recalculate_layout()
  self.panel_h = self:effective_panel_h()
  self.panel_y = self.anchor_y - self.panel_h
  if self.panel_y < 4 then self.panel_y = 4 end
  panel_bg:size(self.panel_w, self.panel_h)
  self:position_elements()
end

function action_picker:tab_y()
  return self.panel_y + PANEL_PAD + HEADER_H + PANEL_PAD
end

-- strip_y(i): top Y of the i-th filter strip (1-based)
function action_picker:strip_y(idx)
  local y = self:tab_y() + TAB_H + PANEL_PAD
  for i = 1, idx - 1 do y = y + STRIP_H + PANEL_PAD end
  return y
end

function action_picker:grid_y_start()
  local n = #self.strips
  if n == 0 then return self:tab_y() + TAB_H + PANEL_PAD end
  return self:strip_y(n) + STRIP_H + PANEL_PAD
end

function action_picker:name_y_pos()
  return self:grid_y_start() + GRID_ROWS * cell_size() - ICON_GAP + PANEL_PAD
end

function action_picker:scroll_y_pos()
  return self:name_y_pos() + NAME_H + PANEL_PAD
end

function action_picker:tab_bounds(i)
  local tw = math.floor((self.panel_w - PANEL_PAD*2) / #CATEGORIES)
  local x1 = self.panel_x + PANEL_PAD + (i-1)*tw
  return x1, self:tab_y(), x1+tw, self:tab_y()+TAB_H
end

-- Returns x1,y1,x2,y2 for the oi-th option in the si-th filter strip
function action_picker:strip_opt_bounds(si, oi)
  local strip = self.strips[si]
  if not strip then return 0,0,0,0 end
  local n  = #strip.opts
  local bw = math.floor((self.panel_w - PANEL_PAD*2) / n)
  local x1 = self.panel_x + PANEL_PAD + (oi-1)*bw
  local y1 = self:strip_y(si)
  return x1, y1, x1+bw, y1+STRIP_H
end

-- ── init ──────────────────────────────────────────────────────────────────
function action_picker:init(theme_options, db)
  database_ref = db
  ICON_SIZE    = math.floor(40 * theme_options.slot_icon_scale)

  local cell   = cell_size()
  self.panel_w = GRID_COLS * cell - ICON_GAP + PANEL_PAD * 2
  self.panel_h = self.panel_w  -- overwritten on open()

  local tsz   = math.floor(10 * theme_options.slot_icon_scale)
  local ssz   = math.floor( 9 * theme_options.slot_icon_scale)
  local lgsz  = math.floor(11 * theme_options.slot_icon_scale)  -- title size
  local hsz   = math.floor( 8 * theme_options.slot_icon_scale)  -- hint size
  local blank = windower.addon_path .. '/images/other/blank.png'
  local bsq   = windower.addon_path .. '/images/other/black-square.png'

  -- Panel background: slightly transparent dark grey
  panel_bg = make_image(bsq, self.panel_w, self.panel_h, 230)
  panel_bg:fit(false)

  -- Two-line header: title prominent, drag hint de-emphasised + italic
  title_label = make_text(lgsz, 255, 255, 255)
  title_label:text('Action Picker')

  hint_label = make_text(hsz, 150, 150, 150, true)  -- italic
  hint_label:text('drag to reposition')

  -- Tab row: inactive tabs slightly dimmer grey; active tab set in refresh_grid
  for i, cat in ipairs(CATEGORIES) do
    local t = make_text(tsz, 210, 210, 210)
    t:text(cat.label)
    tab_texts[i] = t
  end

  -- Filter strip pool: 3 rows × 14 options; brightness decreases with depth
  for si = 1, MAX_STRIPS do
    strip_texts[si] = {}
    local dim = 210 - (si-1)*15
    for oi = 1, MAX_STRIP_OPT do
      strip_texts[si][oi] = make_text(ssz, dim, dim, dim)
    end
  end

  -- Icon grid
  for r = 1, GRID_ROWS do
    grid_icons[r] = {}
    for c = 1, GRID_COLS do
      grid_icons[r][c] = make_image(blank, ICON_SIZE, ICON_SIZE, 230)
    end
  end

  -- Hover name: italic warm-yellow for a distinct look
  name_label = make_text(tsz, 255, 235, 140, true)

  -- Scroll buttons: subdued grey so they don't compete with icons
  scroll_up_btn   = make_text(tsz, 190, 190, 190); scroll_up_btn:text('[ ^ Prev ]')
  scroll_down_btn = make_text(tsz, 190, 190, 190); scroll_down_btn:text('[ v Next ]')

  drag_icon = make_image(blank, ICON_SIZE, ICON_SIZE, 200)

  -- Settings tab text pools
  for i = 1, MAX_ST_ROWS do
    st_labels[i] = make_text(ssz, 215, 215, 215)
    st_btn_a[i]  = make_text(ssz, 175, 175, 175)
    st_btn_b[i]  = make_text(ssz, 175, 175, 175)
    st_btn_c[i]  = make_text(ssz, 175, 175, 175)
  end
  st_apply = make_text(tsz, 120, 235, 145); st_apply:text('[ Apply & Reload ]')
end

-- ── Build action lists ────────────────────────────────────────────────────
function action_picker:build_actions()
  self.actions = {ma={}, tr={}, ja={}, ws={}}
  local pp          = windower.ffxi.get_player()
  local main_job_id = pp and pp.main_job_id or 0
  local sub_job_id  = pp and pp.sub_job_id  or 0

  -- Magic + Trusts
  local known = windower.ffxi.get_spells()
  if known then
    for spell_id, is_known in pairs(known) do
      if is_known and resources.spells[spell_id] then
        local res            = resources.spells[spell_id]
        local spell_type_str = tostring(res.type or ''):lower()
        local is_trust       = (spell_type_str == 'trust')

        -- Job filter: skip non-trust spells the current job/subjob can't use
        local usable = is_trust
                    or (res.levels == nil)
                    or (main_job_id ~= 0 and res.levels[main_job_id])
                    or (sub_job_id  ~= 0 and res.levels[sub_job_id])
        if usable then

        local db = database_ref.ma and database_ref.ma[res.en:lower()]
        if db and db.icon then
          local target = 't'
          if res.targets then
            if res.targets.Self and not (res.targets.Enemy or res.targets.Player
                                     or  res.targets.Party or res.targets.Ally) then
              target = 'me'
            elseif (res.targets.Player or res.targets.Party or res.targets.Ally)
                   and not res.targets.Enemy then
              target = 'stpc'
            end
          end
          local icon_path = safe_icon(windower.addon_path..'/images/icons/spells/'
                                ..string.format('%05d',db.icon)..'.png')
          if is_trust then
            table.insert(self.actions.tr, {
              type      = 'ma', action = res.en, target = target,
              alias     = shorten_ability_name(res.en),
              icon_path = icon_path, name = res.en,
              role      = get_trust_role(res.en),
              scope     = get_scope(res),
            })
          else
            table.insert(self.actions.ma, {
              type        = 'ma', action = res.en, target = target,
              alias       = shorten_ability_name(res.en),
              icon_path   = icon_path, name = res.en,
              spell_type  = tostring(res.type or ''),
              spell_school= get_spell_school(res),
              scope       = get_scope(res),
            })
          end
        end  -- if db and db.icon

        end  -- if usable
      end
    end
  end
  table.sort(self.actions.ma, function(a,b) return a.name < b.name end)
  table.sort(self.actions.tr, function(a,b) return a.name < b.name end)

  -- Job Abilities
  local ab = windower.ffxi.get_abilities()
  local ja_added = {}  -- dedupe by lowercase name (see stratagem note below)

  local function add_job_ability(res)
    if res.en:lower() == 'stratagems' then return end  -- menu placeholder, not a real castable action
    local db = database_ref.ja and database_ref.ja[res.en:lower()]
    if not (db and db.icon) then return end
    if ja_added[res.en:lower()] then return end
    ja_added[res.en:lower()] = true
    local target = 'me'
    if res.targets then
      if res.targets.Enemy and not res.targets.Self then target = 't'
      elseif (res.targets.Player or res.targets.Party)
             and not res.targets.Enemy then target = 'stpc' end
    end
    local icon_path = safe_icon(windower.addon_path..'/images/icons/abilities/'
                          ..string.format('%05d',db.icon)..'.png')
    table.insert(self.actions.ja, {
      type='ja', action=res.en, target=target,
      alias=shorten_ability_name(res.en), icon_path=icon_path, name=res.en,
      scope=get_scope(res),
    })
  end

  if ab and ab.job_abilities then
    for _, aid in pairs(ab.job_abilities) do
      if resources.job_abilities[aid] then
        add_job_ability(resources.job_abilities[aid])
      end
    end
  end

  -- windower.ffxi.get_abilities().job_abilities is sourced from the
  -- client's per-recast-group slot table: it stores one ability id per
  -- recast_id, not one per ability. SCH's stratagems (Penury, Parsimony,
  -- Celerity, Alacrity, Addendum: White/Black, etc.) all share a single
  -- recast_id (SCH_STRAT_RECAST_ID = 231, same constant used in
  -- utility_gauges.lua), so only one of them ever comes through the loop
  -- above — the rest silently never appear. The single id that *does*
  -- come through is also unreliable: it's frequently id 223, "Stratagems"
  -- (en), the menu-opener placeholder (its own separate recast_id of 233)
  -- rather than a real, directly-castable stratagem, which is why it
  -- showed up but did nothing when used.
  --
  -- Fix: walk the full job_abilities resource table for every entry on
  -- recast_id 231 and add it directly, gated by a hardcoded level table
  -- (job_abilities resource entries carry no "levels" field the way spell
  -- resources do, so there's nothing to read here — these levels are
  -- fixed FFXI values, unchanged across all of SCH's lifetime).
  local SCH_STRAT_RECAST_ID = 231
  local JOB_SCH = 20  -- matches utility_gauges.lua's JOB_SCH
  local SCH_STRAT_LEVELS = {
    ['penury']          = 10, ['addendum: white'] = 10,
    ['celerity']        = 25, ['parsimony']       = 10,
    ['alacrity']        = 25, ['addendum: black'] = 30,
    ['accession']       = 40, ['manifestation']   = 40,
    ['rapture']         = 55, ['ebullience']       = 55,
    ['altruism']        = 75, ['focalization']     = 75,
    ['tranquility']     = 75, ['equanimity']       = 75,
    ['perpetuance']     = 87, ['immanence']        = 87,
  }
  local pp = windower.ffxi.get_player()
  local main_job_id = pp and pp.main_job_id or 0
  local sub_job_id  = pp and pp.sub_job_id  or 0
  local main_job_lv = pp and pp.main_job_level or 0
  local sub_job_lv  = pp and pp.sub_job_level  or 0
  for _, res in pairs(resources.job_abilities) do
    if res.recast_id == SCH_STRAT_RECAST_ID then
      local req = SCH_STRAT_LEVELS[res.en:lower()]
      local usable = req and ((main_job_id == JOB_SCH and main_job_lv >= req)
                            or (sub_job_id  == JOB_SCH and sub_job_lv  >= req))
      if usable then add_job_ability(res) end
    end
  end

  table.sort(self.actions.ja, function(a,b) return a.name < b.name end)

  -- Weapon Skills
  if ab and ab.weapon_skills then
    for _, wsid in pairs(ab.weapon_skills) do
      if resources.weapon_skills[wsid] then
        local res = resources.weapon_skills[wsid]
        local db  = database_ref.ws and database_ref.ws[res.en:lower()]
        if db and db.icon then
          local icon_path = safe_icon(windower.addon_path..'/images/icons/weapons/'
                                ..string.format('%02d',db.icon)..'.png')
          table.insert(self.actions.ws, {
            type='ws', action=res.en, target='t',
            alias=shorten_ability_name(res.en), icon_path=icon_path, name=res.en,
            ws_type = get_ws_type(res),
            scope   = get_scope(res),
          })
        end
      end
    end
  end
  table.sort(self.actions.ws, function(a,b) return a.name < b.name end)
end

-- ── Filter strip management ───────────────────────────────────────────────
-- Rebuilds self.strips from TAB_FILTER_CHAIN for self.active_cat.
-- Preserves existing .active selections where still valid.
function action_picker:build_strips_for_tab()
  local chain = TAB_FILTER_CHAIN[self.active_cat]
  if not chain or #chain == 0 then self.strips = {}; return end

  local old_strips = self.strips  -- snapshot for active-preservation
  local acts       = self.actions[self.active_cat] or {}
  self.strips      = {}

  for ci, cd in ipairs(chain) do
    local opts = cd.build(acts)
    if not opts or #opts < 2 then break end  -- no useful filter here; stop

    -- Preserve the old active selection for this dimension if still valid
    local active = 'all'
    for _, os in ipairs(old_strips) do
      if os.dim == cd.dim then
        for _, o in ipairs(opts) do
          if o.key == os.active then active = os.active; break end
        end
        break
      end
    end

    table.insert(self.strips, {dim=cd.dim, get=cd.get, opts=opts, active=active})

    -- Narrow acts for the next strip's build function
    if active ~= 'all' then
      local filtered = {}
      for _, a in ipairs(acts) do
        if cd.get(a) == active then table.insert(filtered, a) end
      end
      acts = filtered
    end
  end
end

-- Called from on_mouse when a strip option is clicked
function action_picker:on_strip_click(si, opt_key)
  if not self.strips[si] then return end
  if self.strips[si].active == opt_key then return end
  self.strips[si].active = opt_key
  -- Reset later strips so build_strips_for_tab re-evaluates them fresh
  for i = si + 1, #self.strips do self.strips[i].active = 'all' end
  self:build_strips_for_tab()
  self:recalculate_layout()
  self:refresh_grid()
end

-- ── Action accessors ─────────────────────────────────────────────────────
function action_picker:current_actions()
  return self.actions[self.active_cat] or {}
end

function action_picker:current_filtered_actions()
  local acts = self:current_actions()
  local out  = {}
  for _, a in ipairs(acts) do
    local pass = true
    for _, strip in ipairs(self.strips) do
      if strip.active ~= 'all' and strip.get(a) ~= strip.active then
        pass = false; break
      end
    end
    if pass then table.insert(out, a) end
  end
  return out
end

function action_picker:max_scroll()
  return math.max(0, math.ceil(#self:current_filtered_actions()/GRID_COLS) - GRID_ROWS)
end

-- ── Refresh ───────────────────────────────────────────────────────────────
function action_picker:position_elements()
  local gx   = self.panel_x + PANEL_PAD
  local gy   = self:grid_y_start()
  local tw   = math.floor((self.panel_w - PANEL_PAD*2) / #CATEGORIES)
  local cell = cell_size()
  local mid  = self.panel_x + math.floor(self.panel_w / 2)

  panel_bg:pos(self.panel_x, self.panel_y)
  -- Two-line header: title on top, hint below
  title_label:pos(self.panel_x + PANEL_PAD, self.panel_y + PANEL_PAD + 1)
  hint_label:pos(self.panel_x + PANEL_PAD, self.panel_y + PANEL_PAD + 17)

  for i = 1, #CATEGORIES do
    tab_texts[i]:pos(self.panel_x + PANEL_PAD + (i-1)*tw + 4, self:tab_y() + 4)
  end

  self:refresh_filter_strips()

  for r = 1, GRID_ROWS do
    for c = 1, GRID_COLS do
      grid_icons[r][c]:pos(gx + (c-1)*cell, gy + (r-1)*cell)
    end
  end

  name_label:pos(self.panel_x + PANEL_PAD, self:name_y_pos() + 2)
  scroll_up_btn:pos(mid - 74, self:scroll_y_pos())
  scroll_down_btn:pos(mid + 6,  self:scroll_y_pos())

  -- Settings tab: reposition all its text elements to match the new panel location
  if self.active_cat == 'st' then self:refresh_settings() end
end

-- Strip inactive colours per depth level (gets slightly dimmer each row)
local STRIP_INACTIVE = {205, 190, 175}

function action_picker:refresh_filter_strips()
  for si = 1, MAX_STRIPS do
    local strip  = self.strips[si]
    local pool   = strip_texts[si]
    local inact  = STRIP_INACTIVE[si] or 160
    if strip then
      local n  = #strip.opts
      local bw = math.floor((self.panel_w - PANEL_PAD*2) / n)
      local y1 = self:strip_y(si)
      for oi = 1, MAX_STRIP_OPT do
        local t = pool[oi]
        if oi <= n then
          t:pos(self.panel_x + PANEL_PAD + (oi-1)*bw + 3, y1 + 3)
          t:text(strip.opts[oi].label)
          local on = (strip.opts[oi].key == strip.active)
          t:color(on and 255 or inact, on and 215 or inact, on and 60 or inact)
          t:show()
        else
          t:hide()
        end
      end
    else
      for oi = 1, MAX_STRIP_OPT do pool[oi]:hide() end
    end
  end
end

function action_picker:refresh_grid()
  if self.active_cat == 'st' then self:refresh_settings(); return end

  -- Restore name label visibility (refresh_settings hides it; must re-show on tab switch)
  name_label:show()

  -- Hide settings elements
  for i = 1, MAX_ST_ROWS do
    st_labels[i]:hide(); st_btn_a[i]:hide(); st_btn_b[i]:hide(); st_btn_c[i]:hide()
  end
  st_apply:hide()

  local acts  = self:current_filtered_actions()
  local start = self.scroll_offset * GRID_COLS
  for r = 1, GRID_ROWS do
    for c = 1, GRID_COLS do
      local idx = start + (r-1)*GRID_COLS + c
      local img = grid_icons[r][c]
      if idx <= #acts then img:path(acts[idx].icon_path); img:alpha(230); img:show()
      else                 img:hide() end
    end
  end

  for i, cat in ipairs(CATEGORIES) do
    local on = (cat.key == self.active_cat)
    tab_texts[i]:color(on and 255 or 220, on and 215 or 220, on and 70 or 220)
  end

  local ms = self:max_scroll()
  if self.scroll_offset > 0   then scroll_up_btn:show()   else scroll_up_btn:hide()   end
  if self.scroll_offset < ms  then scroll_down_btn:show()  else scroll_down_btn:hide() end
end

-- ── Settings tab ─────────────────────────────────────────────────────────
-- ── Appearance application helpers ───────────────────────────────────────
function action_picker:apply_panel_theme(key)
  local theme = nil
  for _, t in ipairs(PANEL_THEMES) do
    if t.key == key then theme = t; break end
  end
  if not theme then return end

  local wsq  = windower.addon_path .. '/images/other/white-square.png'
  local path = wsq
  if theme.path then
    local wp = windower.addon_path .. '/images/' .. theme.path .. '.png'
    local f  = io.open(wp, 'r')
    if f then f:close(); path = wp end
  end

  panel_bg:path(path)
  panel_bg:fit(theme.path ~= nil)   -- stretch wallpapers, keep solid colour crisp
  panel_bg:size(self.panel_w, self.panel_h)
  panel_bg:color(theme.r, theme.g, theme.b)
  panel_bg:alpha(theme.a)

  -- Recolour foreground text elements for legibility against this background
  if title_label then title_label:color(theme.fr, theme.fg, theme.fb) end
  if hint_label  then
    hint_label:color(
      math.floor(theme.fr * 0.6),
      math.floor(theme.fg * 0.6),
      math.floor(theme.fb * 0.6))
  end
  if name_label then name_label:color(theme.fr, theme.fg, math.floor(theme.fb * 0.55)) end
end

function action_picker:apply_font(font_key)
  local function rf(t) if t then t:font(font_key) end end
  rf(title_label); rf(hint_label); rf(name_label)
  rf(scroll_up_btn); rf(scroll_down_btn); rf(st_apply)
  for _, t in ipairs(tab_texts) do rf(t) end
  for si = 1, MAX_STRIPS do
    for oi = 1, MAX_STRIP_OPT do rf(strip_texts[si][oi]) end
  end
  for i = 1, MAX_ST_ROWS do
    rf(st_labels[i]); rf(st_btn_a[i]); rf(st_btn_b[i]); rf(st_btn_c[i])
  end
end

function action_picker:build_settings_defs()
  if not self.settings_ref then self.st_defs = {}; return end
  local s    = self.settings_ref
  local defs = {}

  local function sect(lbl) table.insert(defs, {tp='section', label=lbl}) end
  local function bool_row(lbl, gf, sf, la, lb)
    table.insert(defs, {tp='bool', label=lbl, get=gf, set=sf, la=la, lb=lb})
  end
  local function int_row(lbl, gf, sf, lo, hi, step)
    table.insert(defs, {tp='int', label=lbl, get=gf, set=sf, lo=lo, hi=hi, step=step})
  end
  local function flt_row(lbl, gf, sf, lo, hi, step)
    table.insert(defs, {tp='flt', label=lbl, get=gf, set=sf, lo=lo, hi=hi, step=step})
  end

  sect('── Hotbars ──')
  int_row('Hotbar Count',
    function()  return s.Hotbar.Style.HotbarCount end,
    function(v) s.Hotbar.Style.HotbarCount = v end,
    3, 10, 1)
  local count = s.Hotbar.Style.HotbarCount or 7
  for i = 1, count do
    local n = BAR_NAMES[i]
    if n and s.Hotbar.Offsets and s.Hotbar.Offsets[n] then
      local ii = i
      bool_row('Bar '..ii..' Orient.',
        function()  return s.Hotbar.Offsets[BAR_NAMES[ii]].Vertical end,
        function(v) s.Hotbar.Offsets[BAR_NAMES[ii]].Vertical = v end,
        'Vert.', 'Horiz.')
    end
  end

  sect('── Visibility ──')
  bool_row('Action Names',
    function()  return not s.Hotbar.HideActionName end,
    function(v) s.Hotbar.HideActionName = not v end, 'Show', 'Hide')
  bool_row('Action Cost',
    function()  return not s.Hotbar.HideActionCost end,
    function(v) s.Hotbar.HideActionCost = not v end, 'Show', 'Hide')
  bool_row('Empty Slots',
    function()  return not s.Hotbar.HideEmptySlots end,
    function(v) s.Hotbar.HideEmptySlots = not v end, 'Show', 'Hide')
  bool_row('Action Desc.',
    function()  return s.Hotbar.ShowActionDescription end,
    function(v) s.Hotbar.ShowActionDescription = v end, 'Show', 'Hide')
  bool_row('Hotbar Nums.',
    function()  return not s.General.HideHotbarNumbers end,
    function(v) s.General.HideHotbarNumbers = not v end, 'Show', 'Hide')
  bool_row('Inv. Count',
    function()  return not s.General.HideInventoryCount end,
    function(v) s.General.HideInventoryCount = not v end, 'Show', 'Hide')
  bool_row('Environment',
    function()  return not s.General.HideEnvironment end,
    function(v) s.General.HideEnvironment = not v end, 'Show', 'Hide')

  sect('── Behavior ──')
  bool_row('Weapon Switch',
    function()  return s.General.EnableWeaponSwitching end,
    function(v) s.General.EnableWeaponSwitching = v end, 'On', 'Off')
  bool_row('Confirm Target',
    function()  return s.Hotbar.ConfirmSubtargetIfNecessary end,
    function(v) s.Hotbar.ConfirmSubtargetIfNecessary = v end, 'On', 'Off')
  bool_row('Magic Burst HL.',
    function()  return s.Hotbar.HighlightMagicBurst end,
    function(v) s.Hotbar.HighlightMagicBurst = v end, 'On', 'Off')
  bool_row('Skillchain HL.',
    function()  return s.Hotbar.HighlightSkillchain end,
    function(v) s.Hotbar.HighlightSkillchain = v end, 'On', 'Off')
  bool_row('Anim. Lights',
    function()  return s.Hotbar.UseAnimatedHighlights end,
    function(v) s.Hotbar.UseAnimatedHighlights = v end, 'On', 'Off')
  bool_row('CD Sweep',
    function()  return s.Hotbar.ShowCooldownSweep end,
    function(v) s.Hotbar.ShowCooldownSweep = v end, 'On', 'Off')

  sect('── Opacity ──')
  int_row('Slot Alpha',
    function()  return s.Hotbar.Style.SlotAlpha end,
    function(v) s.Hotbar.Style.SlotAlpha = v end, 0, 255, 5)
  int_row('Disabled Alpha',
    function()  return s.Hotbar.Misc.Disabled.Opacity end,
    function(v) s.Hotbar.Misc.Disabled.Opacity = v end, 0, 100, 5)
  int_row('Feedback Opacity',
    function()  return s.Hotbar.Misc.Feedback.Opacity end,
    function(v) s.Hotbar.Misc.Feedback.Opacity = v end, 50, 255, 10)

  sect('── Style ──')
  flt_row('Icon Scale',
    function()  return s.Hotbar.Style.SlotIconScale end,
    function(v) s.Hotbar.Style.SlotIconScale = v end, 0.5, 2.0, 0.1)
  int_row('Slot Spacing',
    function()  return s.Hotbar.Style.SlotSpacing end,
    function(v) s.Hotbar.Style.SlotSpacing = v end, 4, 30, 2)
  int_row('Hotbar Spacing',
    function()  return s.Hotbar.Style.HotbarSpacing end,
    function(v) s.Hotbar.Style.HotbarSpacing = v end, 30, 120, 4)

  -- ── Appearance ──────────────────────────────────────────────────────────
  sect('── Appearance ──')

  -- Helper: build a cycle row over any ordered list
  local function cycle_row(lbl, list, gf, sf)
    table.insert(defs, {tp='cycle', label=lbl, list=list,
                         get=gf, set=sf})
  end

  cycle_row('Panel BG', PANEL_THEMES,
    function()
      local ap = s.ActionPicker
      return (ap and ap.PanelTheme) or 'dark'
    end,
    function(v)
      if not s.ActionPicker then s.ActionPicker = {} end
      s.ActionPicker.PanelTheme = v
      action_picker:apply_panel_theme(v)
    end)

  cycle_row('Hotbar BG', HOTBAR_THEMES,
    function()
      return (s.Hotbar and s.Hotbar.Theme and s.Hotbar.Theme.BarBackground) or 'none'
    end,
    function(v)
      s.Hotbar.Theme.BarBackground = v
      -- Hotbar backdrop colours take effect on Apply & Reload
    end)

  cycle_row('Panel Font', PANEL_FONTS,
    function()
      local ap = s.ActionPicker
      return (ap and ap.Font) or 'Calibri'
    end,
    function(v)
      if not s.ActionPicker then s.ActionPicker = {} end
      s.ActionPicker.Font = v
      action_picker:apply_font(v)
    end)

  self.st_defs = defs
end

function action_picker:refresh_settings()
  for r = 1, GRID_ROWS do for c = 1, GRID_COLS do grid_icons[r][c]:hide() end end
  name_label:text(''); name_label:hide()

  for i, cat in ipairs(CATEGORIES) do
    local on = (cat.key == self.active_cat)
    tab_texts[i]:color(on and 255 or 220, on and 215 or 220, on and 70 or 220)
  end

  local defs = self.st_defs
  local gy   = self:grid_y_start()
  local R    = self.panel_x + self.panel_w - PANEL_PAD
  local gx   = self.panel_x + PANEL_PAD + 3

  local vis = 0
  for di = self.st_scroll + 1, #defs do
    if vis >= MAX_ST_ROWS then break end
    vis = vis + 1
    local def   = defs[di]
    local row_y = gy + (vis-1)*ST_ROW_H
    local la, ba, bb, bc = st_labels[vis], st_btn_a[vis], st_btn_b[vis], st_btn_c[vis]

    la:pos(gx, row_y + 3)

    if def.tp == 'section' then
      la:color(155, 185, 240); la:text(def.label); la:show()  -- bright steel blue
      ba:hide(); bb:hide(); bc:hide()

    elseif def.tp == 'bool' then
      local val = def.get()
      la:color(215, 215, 215); la:text(def.label); la:show()
      ba:pos(R+ST_BOOL_A, row_y+3)
      ba:color(val and 255 or 175, val and 215 or 175, val and 60 or 175)
      ba:text(def.la); ba:show()
      bb:hide()
      bc:pos(R+ST_BOOL_C, row_y+3)
      bc:color((not val) and 255 or 175,(not val) and 215 or 175,(not val) and 60 or 175)
      bc:text(def.lb); bc:show()

    elseif def.tp == 'int' or def.tp == 'flt' then
      local val = def.get()
      la:color(215, 215, 215); la:text(def.label); la:show()
      ba:pos(R+ST_NUM_A, row_y+3); ba:color(200,200,200); ba:text('-'); ba:show()
      local vs = def.tp=='flt' and string.format('%.1f', val) or tostring(val)
      bb:pos(R+ST_NUM_B, row_y+3); bb:color(255, 235, 120); bb:text(vs); bb:show()
      bc:pos(R+ST_NUM_C, row_y+3); bc:color(200,200,200); bc:text('+'); bc:show()

    elseif def.tp == 'cycle' then
      -- Find and display the current option's label
      local cur     = def.get()
      local cur_lbl = cur
      for _, item in ipairs(def.list) do
        if item.key == cur then cur_lbl = item.label; break end
      end
      la:color(215, 215, 215); la:text(def.label); la:show()
      ba:pos(R+ST_CYC_PREV, row_y+3); ba:color(190,190,190); ba:text('<'); ba:show()
      bb:pos(R+ST_CYC_MID,  row_y+3); bb:color(255, 235, 120); bb:text(cur_lbl); bb:show()
      bc:pos(R+ST_CYC_NEXT, row_y+3); bc:color(190,190,190); bc:text('>'); bc:show()
    end
  end

  for i = vis + 1, MAX_ST_ROWS do
    st_labels[i]:hide(); st_btn_a[i]:hide(); st_btn_b[i]:hide(); st_btn_c[i]:hide()
  end

  local sy  = self:scroll_y_pos()
  local mid = self.panel_x + math.floor(self.panel_w/2)
  local can_up   = self.st_scroll > 0
  local can_down = (self.st_scroll + MAX_ST_ROWS) < #defs
  if can_up   then scroll_up_btn:pos(self.panel_x+PANEL_PAD, sy+2);                  scroll_up_btn:show()
  else             scroll_up_btn:hide() end
  if can_down then scroll_down_btn:pos(self.panel_x+self.panel_w-PANEL_PAD-62, sy+2); scroll_down_btn:show()
  else             scroll_down_btn:hide() end
  st_apply:pos(mid-58, sy+2); st_apply:show()
end

function action_picker:st_hit(x, y)
  local gy = self:grid_y_start()
  if y < gy then return nil end
  local ri = math.floor((y - gy) / ST_ROW_H) + 1
  if ri < 1 or ri > MAX_ST_ROWS then return nil end
  local di = self.st_scroll + ri
  if di > #self.st_defs then return nil end
  local def = self.st_defs[di]
  if def.tp == 'section' then return nil end
  local R = self.panel_x + self.panel_w - PANEL_PAD
  if def.tp == 'bool' then
    if x >= R+ST_BOOL_A-2 and x < R+ST_BOOL_C-2 then return def, 'a'
    elseif x >= R+ST_BOOL_C-2 then return def, 'c' end
  elseif def.tp == 'int' or def.tp == 'flt' then
    if x >= R+ST_NUM_A-2 and x < R+ST_NUM_B-2 then return def, 'a'
    elseif x >= R+ST_NUM_C-2 then return def, 'c' end
  elseif def.tp == 'cycle' then
    -- [<] region extends a bit left; [>] occupies the right edge
    if x >= R+ST_CYC_PREV-2 and x < R+ST_CYC_MID-2 then return def, 'a'
    elseif x >= R+ST_CYC_NEXT-2 then return def, 'c' end
  end
  return nil
end

-- ── Hit testing ───────────────────────────────────────────────────────────
function action_picker:is_over_panel(x, y)
  return x >= self.panel_x and x <= self.panel_x + self.panel_w
     and y >= self.panel_y and y <= self.panel_y + self.panel_h
end

function action_picker:is_over_header(x, y)
  return x >= self.panel_x and x <= self.panel_x + self.panel_w
     and y >= self.panel_y and y <= self.panel_y + PANEL_PAD + HEADER_H
end

function action_picker:get_tab_at(x, y)
  for i = 1, #CATEGORIES do
    local x1,y1,x2,y2 = self:tab_bounds(i)
    if in_box(x,y,x1,y1,x2,y2) then return CATEGORIES[i].key end
  end
end

-- Returns (strip_idx, opt_key) if (x,y) is over a filter strip option
function action_picker:get_strip_hit(x, y)
  for si, strip in ipairs(self.strips) do
    local y1 = self:strip_y(si)
    if y >= y1 and y <= y1 + STRIP_H then
      for oi = 1, #strip.opts do
        local ox1,_,ox2,_ = self:strip_opt_bounds(si, oi)
        if x >= ox1 and x <= ox2 then
          return si, strip.opts[oi].key
        end
      end
    end
  end
  return nil, nil
end

function action_picker:get_icon_at(x, y)
  local cell = cell_size()
  local gx   = self.panel_x + PANEL_PAD
  local gy   = self:grid_y_start()
  local rx, ry = x - gx, y - gy
  if rx < 0 or ry < 0 then return nil end
  local col = math.floor(rx / cell) + 1
  local row = math.floor(ry / cell) + 1
  if col < 1 or col > GRID_COLS or row < 1 or row > GRID_ROWS then return nil end
  if (rx - (col-1)*cell) > ICON_SIZE then return nil end
  if (ry - (row-1)*cell) > ICON_SIZE then return nil end
  local idx  = self.scroll_offset * GRID_COLS + (row-1)*GRID_COLS + col
  local acts = self:current_filtered_actions()
  if idx >= 1 and idx <= #acts then return acts[idx] end
end

-- ── Open / close ──────────────────────────────────────────────────────────
function action_picker:open(anchor_x, anchor_y, settings_ref)
  self.anchor_y     = anchor_y
  self.settings_ref = settings_ref
  self.panel_x      = anchor_x - self.panel_w - 20
  self.active_cat   = 'ma'
  self.strips       = {}
  self.scroll_offset= 0
  self.st_scroll    = 0
  self.needs_reload = false
  self.drag         = {active=false, action=nil}
  self.panel_drag   = {active=false, last_x=0, last_y=0}
  if self.panel_x < 4 then self.panel_x = 4 end

  self:build_actions()
  self:build_strips_for_tab()

  -- Apply saved appearance settings before making the panel visible
  if self.settings_ref then
    local ap = self.settings_ref.ActionPicker
    self:apply_panel_theme((ap and ap.PanelTheme) or 'dark')
    self:apply_font((ap and ap.Font) or 'Calibri')
  end

  self:recalculate_layout()

  panel_bg:show(); title_label:show(); hint_label:show()
  for _, t in ipairs(tab_texts) do t:show() end
  name_label:text(''); name_label:show()
  self:refresh_grid()
  self.visible = true
end

function action_picker:close()
  if not self.visible then return end
  panel_bg:hide(); title_label:hide(); hint_label:hide()
  for _, t in ipairs(tab_texts) do t:hide() end
  for si = 1, MAX_STRIPS do
    for oi = 1, MAX_STRIP_OPT do strip_texts[si][oi]:hide() end
  end
  for r = 1, GRID_ROWS do for c = 1, GRID_COLS do grid_icons[r][c]:hide() end end
  name_label:hide(); scroll_up_btn:hide(); scroll_down_btn:hide(); drag_icon:hide()
  for i = 1, MAX_ST_ROWS do
    st_labels[i]:hide(); st_btn_a[i]:hide(); st_btn_b[i]:hide(); st_btn_c[i]:hide()
  end
  st_apply:hide()
  self.drag       = {active=false, action=nil}
  self.panel_drag = {active=false, last_x=0, last_y=0}
  self.visible    = false
end

-- ── Mouse handling ────────────────────────────────────────────────────────
function action_picker:on_mouse(ev_type, x, y)
  if not self.visible then return nil end

  -- Consume all non-standard events (right-click, scroll, middle-click) over panel
  if ev_type ~= 0 and ev_type ~= 1 and ev_type ~= 2 then
    if self:is_over_panel(x,y) then return 'consumed' end
    return nil
  end

  if ev_type == 1 then  -- ── Mouse press ────────────────────────────────

    -- Header: start panel drag
    if not self.drag.active and self:is_over_header(x,y) then
      self.panel_drag = {active=true, last_x=x, last_y=y}; return 'consumed'
    end

    -- Tab row
    local cat = self:get_tab_at(x,y)
    if cat then
      if cat ~= self.active_cat then
        self.active_cat    = cat
        self.strips        = {}  -- clear strips unconditionally (including when switching TO settings)
        self.scroll_offset = 0
        self.st_scroll     = 0
        if cat == 'st' then
          self:build_settings_defs()
        else
          self:build_strips_for_tab()
        end
        self:recalculate_layout(); self:refresh_grid()
      end
      return 'consumed'
    end

    -- Settings tab body
    if self.active_cat == 'st' then
      local sy  = self:scroll_y_pos()
      local mid = self.panel_x + math.floor(self.panel_w/2)
      -- Apply button
      if in_box(x,y, mid-58,sy, mid+64,sy+SCROLL_H) then
        self.needs_reload = true
        self:build_settings_defs(); self:refresh_settings()
        return 'consumed'
      end
      -- Scroll up
      if self.st_scroll > 0 and in_box(x,y, self.panel_x+PANEL_PAD,sy, self.panel_x+80,sy+SCROLL_H) then
        self.st_scroll = self.st_scroll - 1; self:refresh_settings(); return 'consumed'
      end
      -- Scroll down
      if (self.st_scroll+MAX_ST_ROWS) < #self.st_defs
         and in_box(x,y, self.panel_x+self.panel_w-80,sy, self.panel_x+self.panel_w,sy+SCROLL_H) then
        self.st_scroll = self.st_scroll + 1; self:refresh_settings(); return 'consumed'
      end
      -- Setting row
      local def, which = self:st_hit(x,y)
      if def and which then
        if def.tp == 'bool' then
          def.set(which == 'a')
        elseif def.tp == 'int' then
          local v = def.get()
          v = (which=='a') and math.max(def.lo, v-def.step) or math.min(def.hi, v+def.step)
          def.set(v)
        elseif def.tp == 'flt' then
          local v = def.get()
          v = (which=='a') and math.max(def.lo, v-def.step) or math.min(def.hi, v+def.step)
          local factor = math.floor(1/def.step + 0.5)
          v = math.floor(v*factor + 0.5)/factor
          def.set(v)
        elseif def.tp == 'cycle' then
          local cur = def.get()
          local ci  = 1
          for i, item in ipairs(def.list) do
            if item.key == cur then ci = i; break end
          end
          ci = (which == 'a') and ci - 1 or ci + 1
          if ci < 1 then ci = #def.list elseif ci > #def.list then ci = 1 end
          def.set(def.list[ci].key)
        end
        self:build_settings_defs(); self:refresh_settings()
        return 'consumed'
      end
      if self:is_over_panel(x,y) then return 'consumed' end
      return nil
    end

    -- Filter strip click    -- Filter strip click (generic — works for any number of strips)
    local si, opt_key = self:get_strip_hit(x,y)
    if si then
      self:on_strip_click(si, opt_key); return 'consumed'
    end

    -- Scroll buttons
    local mid = self.panel_x + math.floor(self.panel_w/2)
    local sy  = self:scroll_y_pos()
    local ms  = self:max_scroll()
    if self.scroll_offset > 0 and in_box(x,y, mid-74,sy, mid-4,sy+SCROLL_H) then
      self.scroll_offset = self.scroll_offset - 1; self:refresh_grid(); return 'consumed'
    end
    if self.scroll_offset < ms and in_box(x,y, mid+6,sy, mid+80,sy+SCROLL_H) then
      self.scroll_offset = self.scroll_offset + 1; self:refresh_grid(); return 'consumed'
    end

    -- Icon pick: begin drag
    local action = self:get_icon_at(x,y)
    if action then
      self.drag = {active=true, action=action}
      drag_icon:path(action.icon_path)
      drag_icon:pos(x - math.floor(ICON_SIZE/2), y - math.floor(ICON_SIZE/2))
      drag_icon:show()
      dbg(string.format('drag started: "%s" (type=%s, target=%s) picked up at (%d,%d)',
        action.action, action.type, tostring(action.target), x, y))
      return 'consumed'
    end

    if self:is_over_panel(x,y) then return 'consumed' end

  elseif ev_type == 0 then  -- ── Mouse move ─────────────────────────────

    if self.panel_drag.active then
      self.panel_x  = self.panel_x  + (x - self.panel_drag.last_x)
      self.anchor_y = self.anchor_y + (y - self.panel_drag.last_y)
      self.panel_drag.last_x = x; self.panel_drag.last_y = y
      -- Move only the background during drag for smooth performance.
      -- All text elements snap to the final position on mouse release.
      self.panel_y = self.anchor_y - self.panel_h
      if self.panel_y < 4 then self.panel_y = 4 end
      panel_bg:pos(self.panel_x, self.panel_y)
      return 'consumed'
    end
    if self.drag.active then
      drag_icon:pos(x - math.floor(ICON_SIZE/2), y - math.floor(ICON_SIZE/2))
      return 'dragging'
    end
    if self:is_over_panel(x,y) then
      if self.active_cat ~= 'st' then
        local action = self:get_icon_at(x,y)
        name_label:text(action and action.name or '')
      end
      return 'consumed'
    end

  elseif ev_type == 2 then  -- ── Mouse release ───────────────────────────

    if self.panel_drag.active then
      self.panel_drag.active = false
      self:recalculate_layout()  -- reposition all elements to final drag position
      return 'consumed'
    end
    if self.drag.active then
      local dropped = self.drag.action
      self.drag = {active=false, action=nil}; drag_icon:hide()
      dbg(string.format('drag released: "%s" dropped at screen (%d,%d) -- handing off to ui:get_slot_at', dropped.action, x, y))
      return dropped
    end
    if self:is_over_panel(x,y) then return 'consumed' end
  end

  return nil
end

-- ── Destroy ───────────────────────────────────────────────────────────────
function action_picker:destroy()
  self:close()
  panel_bg = nil; title_label = nil; hint_label = nil
  tab_texts = {}; strip_texts = {}
  grid_icons = {}; name_label = nil
  scroll_up_btn = nil; scroll_down_btn = nil; drag_icon = nil
  st_labels = {}; st_btn_a = {}; st_btn_b = {}; st_btn_c = {}; st_apply = nil
end

return action_picker
