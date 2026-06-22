--[[    BSD License Disclaimer
        Copyright © 2020, SirEdeonX, Akirane, Technyze
        All rights reserved.

        Redistribution and use in source and binary forms, with or without
        modification, are permitted provided that the following conditions are met:

            * Redistributions of source code must retain the above copyright
              notice, this list of conditions and the following disclaimer.
            * Redistributions in binary form must reproduce the above copyright
              notice, this list of conditions and the following disclaimer in the
              documentation and/or other materials provided with the distribution.
            * Neither the name of ui.xivhotbar/xivhotbar2 nor the
              names of its contributors may be used to endorse or promote products
              derived from this software without specific prior written permission.

        THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
        ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
        WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
        DISCLAIMED. IN NO EVENT SHALL SirEdeonX OR Akirane BE LIABLE FOR ANY
        DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
        (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
        LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
        ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
        (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
        SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

--[[
-- Big thanks to:
-- - Akaden & Rubenator: For the inspiration to the moving icons/hotbars part
-- - Maverickdfz:        Inspiration to the mouse actions
--]]

_addon.name = 'XIVHotbar2'
_addon.author = 'Sabarjp, Fethur', 'Edeon, Akirane', 'Technyze'
_addon.version = '0.3'
_addon.language = 'english'
_addon.commands = { 'xivhotbar', 'htb', 'execute', 'xivhotbar2' }

----------------------------------------
-- End of user defined macro placeholder
----------------------------------------

-- Libs --
config = require('config')
file = require('files')
texts = require('texts')
images = require('images')
tables = require('tables')
packets = require('packets')
resources = require('resources')
require('luau')

-- User settings --
local defaults = require('defaults')

-- Load theme options according to settings --
local settings
local theme
local theme_options

first_0x050 = false



-- Addon Dependencies --
htb_skillchains       = require('lib/skillchains')
htb_bloodpacts        = require('lib/bloodpacts')
htb_blue_spells       = require('lib/blue_spells')

player                = require('lib/player')
ui                    = require('lib/ui')

local keyboard        = require('lib/keyboard_mapper')

local move_box        = require('lib/move_box')
local move_box        = require('lib/move_box')
local utility_gauges  = require('lib/utility_gauges')

local last_job_key    = '' -- tracks job combo to avoid redundant gauge rebuilds

local state           = {
  ready = false,
  demo = false,
  inventory_ready = false,
  inventory_loading = false
}

local loaded          = windower.ffxi.get_info().logged_in
local first_load_done = false

-------
-- Main
-------
nil_equip_bool        = false

-- initialize addon --
function initialize()
  keyboard:set_bindings(settings.Keybinds)
  keyboard:parse_keybinds()

  ui:setup(theme_options)
  ui:set_player(player)

  move_box:init(theme_options)
  local windower_player = windower.ffxi.get_player()
  local windower_info = windower.ffxi.get_info()

  local server = resources.servers[windower_info.server]
      and resources.servers[windower_info.server].en
      or "PrivateServer_" .. tostring(windower_info.server)

  if theme_options.enable_weapon_switching == true then
    -- unlikely to be available unless the world has already been loaded in
    local items = windower.ffxi.get_items()
    if items ~= nil then
      if not (items.equipment.main_bag == 0 and items.equipment.main == 0) then
        set_weapon_type(false, items.equipment.main_bag, items.equipment.main)
      end
      if not (items.equipment.range_bag == 0 and items.equipment.range == 0) then
        set_weapon_type(true, items.equipment.range_bag, items.equipment.range)
      end
    end
  end

  local current_mp = windower_player.vitals.mp
  local current_tp = windower_player.vitals.tp

  ui:update_mp(current_mp)
  ui:update_tp(current_tp)

  local pet = windower.ffxi.get_mob_by_target('pet') or nil
  if pet ~= nil then
    player:update_pet(pet.name)
  end

  player:initialize(windower_player, server, theme_options)
  player:load_hotbar()
  keyboard:bind_keys(theme_options.rows, theme_options.columns)
  skillchains:initialize()

  ui:load_player_hotbar(player:get_hotbar_info())
  ui.hotbar.ready = true
  ui.hotbar.initialized = true
  state.ready = true
end

-- some things can't be accessed until world is loaded
function on_world_load()
  if ui.theme.dev_mode then log("Zoning. Reloading Hotbar.") end

  if theme_options.enable_weapon_switching == true then
    local items = windower.ffxi.get_items()
    set_weapon_type(false, items.equipment.main_bag, items.equipment.main)
    set_weapon_type(true, items.equipment.range_bag, items.equipment.range)
  end

  ui.hotbar.hide_hotbars = false
  ui:show(player:get_hotbar_info())

  reload_hotbar()
end

-- trigger hotbar action --
function trigger_action(slot)
  player:execute_action(slot)
  ui:trigger_feedback(player:get_active_hotbar(), slot)
end

-- toggle between field and battle hotbars --
function toggle_environment()
  player:toggle_environment()

  ui:load_player_hotbar(player:get_hotbar_info())
end

-- set battle environment --
function set_battle_environment(in_battle)
  player:set_battle_environment(in_battle)
  ui:load_player_hotbar(player:get_hotbar_info())
end

-- reload hotbar --
function reload_hotbar(using_pet_name)
  if ui.theme.dev_mode then log("Reloading Hotbar.") end

  -- NOTE: this used to start with coroutine.sleep(1). That sleep ran inside
  -- the 'mouse' event coroutine whenever reload_hotbar() was called from a
  -- mouse-driven path (e.g. dropping an action from the action picker onto
  -- a hotbar slot). While that coroutine was suspended, this function had
  -- not yet returned, so every mouse event Windower fired in that 1-second
  -- window re-entered the handler fresh. If one of those stray events
  -- happened to land on the lock button, it would call toggle_edit_mode(),
  -- silently turning off edit mode (and closing the action picker) mid-drag.
  -- That is exactly why copying actions to the bar would stop working
  -- after repeated use: edit mode had quietly been switched off. The two
  -- call sites that genuinely need a delay (blue magic settling, pet death)
  -- already issue their own explicit coroutine.sleep() before calling this
  -- function, so no caller depends on the sleep being here.

  -- the pet name tends to be unreliable, so we pass it in as a param when possible
  local pet_name = using_pet_name or ''
  if using_pet_name == nil then
    local pet = windower.ffxi.get_mob_by_target('pet') or nil
    if pet ~= nil then
      pet_name = pet.name
    end
  end

  local windower_player = windower.ffxi.get_player()

  if resources.jobs[windower_player.sub_job_id] == nil then -- If character has no subjob
    ui:update_mp(windower_player.vitals.mp)
    ui:update_tp(windower_player.vitals.tp)
    player:update_job(windower_player.main_job_id, resources.jobs[windower_player.main_job_id].ens, 0, 'NON')
    player:update_level(windower_player.main_job_level, 0)
    player:update_pet(pet_name)
  else
    ui:update_mp(windower_player.vitals.mp)
    ui:update_tp(windower_player.vitals.tp)
    player:update_job(windower_player.main_job_id, resources.jobs[windower_player.main_job_id].ens,
      windower_player.sub_job_id, resources.jobs[windower_player.sub_job_id].ens)
    player:update_level(windower_player.main_job_level, windower_player.sub_job_level)
    player:update_pet(pet_name)
  end

  player:load_hotbar()
  ui:load_player_hotbar(player:get_hotbar_info())

  -- Rebuild gauges only when the job combination actually changes
  local job_key = tostring(player.main_job_id) .. '_' .. tostring(player.sub_job_id)
  if job_key ~= last_job_key then
    last_job_key = job_key
    local def_x, def_y = 50, 50
    if ui.lock_panel then
      def_x = ui.lock_panel.x
      def_y = ui.lock_panel.y + ui.image_height + 6
    end
    utility_gauges:setup(player, settings, def_x, def_y)
    -- If already in edit mode when job changes trigger a new setup(),
    -- the freshly-created panels start with edit_mode=false and
    -- set_edit_mode(true) was never called on them.  Sync here.
    if state.demo then
      utility_gauges:set_edit_mode(true)
    end
  end
end

-- change active hotbar --
function change_active_hotbar(new_hotbar)
  player:change_active_hotbar(new_hotbar)
end

--------------------
-- Addon Commands -- --
--------------------

function flush_old_keybinds()
  for i = 1, ui.hotbar.rows, 1 do
    for j = 1, ui.hotbar.columns, 1 do
      windower.send_command('htb delete f ' .. i .. ' ' .. j)
    end
  end
  for i = 1, ui.hotbar.rows, 1 do
    for j = 1, ui.hotbar.columns, 1 do
      windower.send_command('htb delete battle ' .. i .. ' ' .. j)
    end
  end
end

-----------------
-- Bind Events --
-----------------

-- ON LOGOUT --
windower.register_event('logout', function()
  coroutine.sleep(3)
  if windower.ffxi.get_player() == nil then
    windower.send_command('lua reload xivhotbar2')
    ui:hide()
    keyboard:unbind_keys(theme_options.rows, theme_options.columns)
  end
end)


local function save_hotbar(hotbar, index)
  if index <= theme_options.rows then
    local x, y = move_box:get_pos(index)
    hotbar.OffsetX = x
    hotbar.OffsetY = y
  end
end

local function save_all_hotbars()
  save_hotbar(settings.Hotbar.Offsets.First, 1)
  save_hotbar(settings.Hotbar.Offsets.Second, 2)
  save_hotbar(settings.Hotbar.Offsets.Third, 3)
  save_hotbar(settings.Hotbar.Offsets.Fourth, 4)
  save_hotbar(settings.Hotbar.Offsets.Fifth, 5)
  save_hotbar(settings.Hotbar.Offsets.Sixth, 6)
  save_hotbar(settings.Hotbar.Offsets.Seventh, 7)
  config.save(settings)
end

local function toggle_edit_mode()
  state.demo = not state.demo
  if state.demo then
    log(
      "Layout mode enabled! Drag slot icons to swap actions. Drag between rows to reposition bars. Click the unlock button (or //htb move) to save and exit.")
    print('XIVHOTBAR2: Layout mode enabled')
    move_box:enable()
    ui:update_edit_button(true)
    if ui.lock_panel then ui.lock_panel:set_edit_mode(true) end
    utility_gauges:set_edit_mode(true)
    -- Open the action picker anchored to bar 1 slot 1
    local bx, by = ui:get_slot_xy(1, 1)
    ui.action_picker:open(bx, by, settings)
  else
    -- Save lock panel position before writing settings
    if ui.lock_panel then
      settings.Utility = settings.Utility or {}
      settings.Utility.LockButton = settings.Utility.LockButton or {}
      settings.Utility.LockButton.OffsetX = ui.lock_panel.x
      settings.Utility.LockButton.OffsetY = ui.lock_panel.y
      ui.lock_panel:set_edit_mode(false)
    end
    utility_gauges:set_edit_mode(false)
    utility_gauges:save_positions(settings)
    save_all_hotbars()
    print('XIVHOTBAR2: Layout mode disabled, writing new positions to settings.xml.')
    move_box:disable()
    ui:update_edit_button(false)
    ui.action_picker:close()
  end
end


local function print_help()
  log("Commands:")
  log("move: Enables moving the hotbars by dragging them, also writes the changes to settings.xml if used again.")
  log("reload: Reloads the hotbar, if you have made changes to the hotbar-file, this is faster for loading.")
  log("mount: either dismounts if mounted, or mounts the indicated mount")
  log(
    "clear/delete <row> <slot>: scrubs a slot from memory and file, regardless of whether it currently shows as occupied. clear and delete are aliases.")
  log(
    "debug <on|off>: toggles verbose logging of every action-picker drag, drop, file write, swap/remove, and load-time table merge, for diagnosing why an action won't take or shows wrong. Omit on/off to toggle.")
end

-- ON COMMAND --
windower.register_event('addon command', function(command, ...)
  command = command and command:lower() or 'help'
  local args = { ... }

  if command == 'reload' then
    if ui.theme.dev_mode then log('Reloading Hotbar.') end
    reload_hotbar()
  elseif command == 'debug' then
    local arg = args[1] and args[1]:lower() or nil
    local new_value
    if arg == 'on' then
      new_value = true
    elseif arg == 'off' then
      new_value = false
    else
      new_value = not ui.theme.dev_mode
    end
    ui.theme.dev_mode = new_value    -- shared theme_options table: action_manager, file_manager,
    settings.Dev.DevMode = new_value -- action_picker, and ui.lua all see this immediately
    config.save(settings)
    print(string.format(
      'XIVHOTBAR2: Debug logging %s. Try the drag/drop or move you were testing and watch the console.',
      new_value and 'ENABLED' or 'disabled'))
  elseif command == 'help' then
    print_help()
  elseif command == 'mount' then
    local player_mount = windower.ffxi.get_player()
    for k = 1, 32 do
      if player_mount.buffs[k] == 252 then
        windower.chat.input('/dismount')
        return
      end
    end
    if args[1] == nil then
      windower.chat.input('/mount raptor <me>')
    else
      windower.chat.input('/mount ' .. args[1] .. ' <me>')
    end
  elseif command == 'execute' then
    -- special command that is triggered by a windower keybind into an action
    -- on this addon
    change_active_hotbar(tonumber(args[1]))
    if tonumber(args[2]) <= theme_options.columns then
      trigger_action(tonumber(args[2]))
    end
  elseif command == 'move' then
    toggle_edit_mode()
  elseif command == 'hide' then
    ui.hotbar.hide_hotbars = true
    ui:hide()
    utility_gauges:hide_all()
  elseif command == 'show' then
    ui.hotbar.hide_hotbars = false
    ui:show(player:get_hotbar_info())
    utility_gauges:show_all()
  elseif command == 'set' then
    -- //htb set <row> <slot> <type> <action> [target] [alias]
    -- Use underscores for spaces in multi-word names: Cure_IV, Phantom_Roll
    local row    = tonumber(args[1])
    local slot   = tonumber(args[2])
    local atype  = args[3]
    local action = args[4] and args[4]:gsub('_', ' ') or nil
    local target = args[5] or 't'
    local alias  = args[6] and args[6]:gsub('_', ' ') or action

    if not (row and slot and atype and action) then
      windower.add_to_chat(8, '[XIVHotbar2] Usage:  //htb set <row> <slot> <type> <action> [target] [alias]')
      windower.add_to_chat(8, '[XIVHotbar2] Types:  ma  ja  ws  input  macro  autoitem  gs')
      windower.add_to_chat(8, '[XIVHotbar2] Targets: t  me  stpc  stnpc  bt')
      windower.add_to_chat(8, '[XIVHotbar2] Example: //htb set 1 1 ma Cure_IV stpc Cure4')
      windower.add_to_chat(8, '[XIVHotbar2] Note:    use underscores for spaces -> Phantom_Roll')
    else
      -- Remove any existing action at that slot
      local hotbar, env = player:get_hotbar_info_without_vitals()
      if hotbar[env]['hotbar_' .. row] and
          hotbar[env]['hotbar_' .. row]['slot_' .. slot] ~= nil then
        player:remove_action({ source = { row = row, slot = slot } })
      end
      -- Write to job file if it exists, otherwise general file
      local job_path = windower.addon_path .. 'data/' .. player.name .. '/' .. player.main_job .. '.lua'
      local jf = io.open(job_path, 'r')
      local prio = jf and 'm' or 'g'
      if jf then jf:close() end
      player:insert_action({ prio, tostring(row), tostring(slot),
        atype, action, target, alias })
      player:load_hotbar()
      ui:load_player_hotbar(player:get_hotbar_info())
      windower.add_to_chat(8, string.format(
        '[XIVHotbar2] Row %d Slot %d -> %s "%s" <%s>  label: %s',
        row, slot, atype, action, target, alias))
    end
  elseif command == 'clear' or command == 'delete' then
    -- //htb clear <row> <slot>  (delete is an alias) -- scrub a slot from memory AND file,
    -- regardless of whether memory currently thinks it's occupied.
    local row  = tonumber(args[1])
    local slot = tonumber(args[2])
    if not (row and slot) then
      windower.add_to_chat(8, string.format('[XIVHotbar2] Usage: //htb %s <row> <slot>', command))
    else
      local cleared = player:clear_slot(row, slot)
      player:load_hotbar()
      ui:load_player_hotbar(player:get_hotbar_info())
      if cleared then
        windower.add_to_chat(8, string.format('[XIVHotbar2] Cleared row %d slot %d', row, slot))
      else
        windower.add_to_chat(8, string.format('[XIVHotbar2] Row %d slot %d was already empty', row, slot))
      end
    end
  elseif command == 'rename' then
    -- //htb rename <row> <slot> <new_label>
    -- Changes only the visible name shown under the slot icon.
    -- Use underscores for spaces: My_Cure, Big_Nuke
    local row   = tonumber(args[1])
    local slot  = tonumber(args[2])
    local label = args[3] and args[3]:gsub('_', ' ') or nil

    if not (row and slot and label) then
      windower.add_to_chat(8, '[XIVHotbar2] Usage:   //htb rename <row> <slot> <new_label>')
      windower.add_to_chat(8, '[XIVHotbar2] Example: //htb rename 1 1 Cure4')
      windower.add_to_chat(8, '[XIVHotbar2] Note:    use underscores for spaces -> My_Nuke')
    else
      local hotbar, env = player:get_hotbar_info_without_vitals()
      local action = hotbar[env]['hotbar_' .. row]
          and hotbar[env]['hotbar_' .. row]['slot_' .. slot]

      if not action then
        windower.add_to_chat(8, string.format(
          '[XIVHotbar2] Row %d slot %d is empty -- nothing to rename', row, slot))
      else
        -- Write to job file if it exists, otherwise general file
        local job_path = windower.addon_path .. 'data/' .. player.name .. '/' .. player.main_job .. '.lua'
        local jf = io.open(job_path, 'r')
        local prio = jf and 'm' or 'g'
        if jf then jf:close() end
        player:remove_action({ source = { row = row, slot = slot } })
        player:insert_action({ prio, tostring(row), tostring(slot),
          action.type, action.action, action.target or '', label })
        player:load_hotbar()
        ui:load_player_hotbar(player:get_hotbar_info())
        windower.add_to_chat(8, string.format(
          '[XIVHotbar2] Row %d slot %d label -> "%s"', row, slot, label))
      end
    end
  elseif command == 'sc' then
    -- debugging for skillchain detection
    local target = windower.ffxi.get_mob_by_target('t')
    if target then
      local combos = skillchains:get_potential_skillchains(target.id)
      local mb_elements = skillchains:get_magic_burst_elements(target.id)

      if combos then
        windower.add_to_chat(8, '--------COMBOS-------')
        for key, _ in pairs(combos) do
          windower.add_to_chat(8, tostring(key))
        end
      end

      if mb_elements then
        windower.add_to_chat(8, '--------MB-------')
        for key, _ in pairs(mb_elements) do
          windower.add_to_chat(8, tostring(key))
        end
      end

      windower.add_to_chat(8, '--------POT-------')
      local potential = skillchains:get_potential_skillchains(target.id)
      printTable(potential)

      if args[1] then
        local props = {}
        for i, value in ipairs(args) do
          table.insert(props, args[i])
        end
        skillchains:attempt_skillchain(target.id, props)
      end
    end
  end
end)


-- ON KEY --
windower.register_event('keyboard', function(dik, flags, blocked)
  if ui.hotbar.ready == false or windower.ffxi.get_info().chat_open then
    return
  end

  if ui.hotbar.hide_hotbars then
    return
  end

  if dik == theme_options.controls_battle_mode and flags == true then
    toggle_environment()
  end
end)


local current_hotbar = -1
local current_action = -1

local function mouse_hotbars(type, x, y, delta, blocked)
  return_value = false

  if not ui.hotbar.hide_hotbars then
    if type == 1 then -- Mouse left click
      local hotbar, action = ui:hovered(x, y)
      if (action ~= nil) then
        current_hotbar = hotbar
        current_action = action
        return_value = true
      else
        return_value = false
      end
    elseif type == 2 then -- Mouse left release
      if (current_action ~= -1) then
        local hotbar, action = ui:hovered(x, y)
        if (action ~= nil) then
          if (action == 100) then
            toggle_environment()
          elseif (hotbar == current_hotbar and action == current_action) then
            player:change_active_hotbar(hotbar)
            trigger_action(action)
          end
        end
        current_hotbar = -1
        current_action = -1
        return_value = true
      else
        return_value = false
      end
    elseif type == 0 then -- Mouse move
      local hotbar, action = ui:hovered(x, y)
      if (action ~= nil and hotbar ~= nil) then
        ui:light_up_action(x, y, hotbar, action)
        return_value = true
      else
        ui:hide_hover()
        return_value = false
      end
    end
  end

  return return_value
end

-- Mouse Events
windower.register_event('mouse', function(type, x, y, delta, blocked)
  return_value = nil
  if state.ready == true and blocked == false then
    -- 1. Lock panel — grip drag (edit mode) and lock icon click (always).
    -- Both press and release are consumed so the game engine never sees them.
    if ui.lock_panel then
      local lp_result = ui.lock_panel:on_mouse(type, x, y)
      if lp_result == 'content_click' then
        toggle_edit_mode()
        return true
      elseif lp_result ~= nil then
        return true
      end
    end
    -- 1b. Gauge panels — grip drag only (edit mode gated inside handle_mouse).
    if utility_gauges:handle_mouse(type, x, y) then
      return true
    end

    -- 2. Action picker — only active while in edit/demo mode
    if state.demo and ui.action_picker and ui.action_picker.visible then
      local result = ui.action_picker:on_mouse(type, x, y)

      -- Settings tab: Apply & Reload was clicked
      if ui.action_picker.needs_reload then
        ui.action_picker.needs_reload = false
        config.save(settings)
        windower.send_command('lua reload xivhotbar2')
        return true
      end

      -- on_mouse returns a string ('consumed'/'dragging') or an action table on drop.
      -- We cannot use Lua's type() here because the event parameter is also named 'type'.
      if result ~= nil and result ~= 'consumed' and result ~= 'dragging' then
        -- ---- DROP: drag from picker released over a hotbar slot ----
        local h, slot = ui:get_slot_at(x, y)
        if ui.theme.dev_mode then
          log(string.format('[DROP] get_slot_at(%d,%d) -> %s', x, y,
            h and (tostring(h) .. '/' .. tostring(slot)) or 'NIL (no hotbar slot at this screen position)'))
        end
        if h and slot then
          -- Remove whatever is already at that slot so insert_action can write fresh
          local hotbar, env = player:get_hotbar_info_without_vitals()
          local occupied = hotbar[env]['hotbar_' .. h]['slot_' .. slot] ~= nil
          if ui.theme.dev_mode then
            log(string.format('[DROP] target slot %s/%d/%d occupied=%s', env, h, slot, tostring(occupied)))
          end
          local removed_ok = true
          if occupied then
            removed_ok = player:remove_action({ source = { row = h, slot = slot } })
            if ui.theme.dev_mode then
              log(string.format('[DROP] remove_action -> %s', tostring(removed_ok)))
            end
          end
          -- Insert the dropped action (priority 'm' = main job file)
          local inserted_ok = player:insert_action({
            'm',
            tostring(h),
            tostring(slot),
            result.type,
            result.action,
            result.target,
            result.alias,
          })
          if ui.theme.dev_mode then
            log(string.format('[DROP] insert_action("%s") -> %s%s', result.action, tostring(inserted_ok),
              (not inserted_ok) and
              ' -- action did NOT take. If the slot was occupied, check whether remove_action above also failed.' or ''))
          end
          reload_hotbar()
        end
        return true
      elseif result == 'consumed' or result == 'dragging' then
        return true -- picker handled it; don't pass to move_box
      end
      -- result == nil → not over picker; fall through to move_box below
    end

    -- 4. Normal routing: edit-mode row/slot drag or regular hotbar interaction
    if state.demo == true then
      return_value = move_box:move_hotbars(type, x, y, delta, blocked)
    else
      return_value = mouse_hotbars(type, x, y, delta, blocked)
    end
  end

  return return_value
end)

-- ON PRERENDER --
local frame_counter = 0
windower.register_event('prerender', function()
  frame_counter = frame_counter + 1

  if ui.hotbar.ready == false then
    return
  end

  if ui.feedback.is_active then
    ui:show_feedback()
  end

  if ui.is_setup and ui.hotbar.hide_hotbars == false then
    moved_row_info = move_box:get_move_box_info()
    if (moved_row_info.swapped_slots.active == true) then
      if ui.theme.dev_mode then
        local s, d = moved_row_info.swapped_slots.source, moved_row_info.swapped_slots.dest
        log(string.format('[SWAP] %d/%d -> %d/%d', s.row, s.slot, d.row, d.slot))
      end
      player:swap_actions(moved_row_info.swapped_slots)
      ui:swap_icons(moved_row_info.swapped_slots)
      moved_row_info.swapped_slots.active = false
      ui:load_player_hotbar(player:get_hotbar_info())
    elseif (moved_row_info.row_active == true) then
      ui:move_icons(moved_row_info, ui.theme)
    elseif (moved_row_info.removed_slot.active == true) then
      player:remove_action(moved_row_info.removed_slot)
      moved_row_info.removed_slot.active = false
      ui:load_player_hotbar(player:get_hotbar_info())
    end

    -- Only execute the expensive recast logic every 3 ticks
    if frame_counter % 3 == 0 then
      ui:check_recasts(player:get_hotbar_info())
    end

    ui:check_hover()
  end
end)

-- ON MP CHANGE --
windower.register_event('mp change', function(new, old)
  player.vitals.mp = new
  ui:update_mp(new)
end)

-- OM TP CHANGE --
windower.register_event('tp change', function(new, old)
  player.vitals.tp = new
  ui:update_tp(new)
end)

-- ON STATUS CHANGE --
windower.register_event('status change', function(new_status_id)
  -- hide/show bar in cutscenes --
  if ui.hotbar.hide_hotbars == false and new_status_id == 4 then
    ui.hotbar.hide_hotbars = true
    ui:hide()
  elseif ui.hotbar.hide_hotbars and new_status_id ~= 4 then
    ui.hotbar.hide_hotbars = false
    ui:show(player:get_hotbar_info())
  end
end)

-- ON LOGIN/LOAD --
windower.register_event('load', function()
  local windower_player = windower.ffxi.get_player()
  if windower_player ~= nil then
    defaults = require('defaults')
    defaults.Keybinds = keyboard.default_keybinds
    settings = config.load(defaults)
    keyboard:cast_all_to_strings(settings)
    config.save(settings)

    -- Load theme options according to settings --
    theme = require('theme')
    theme_options = theme.apply(settings)
    player.id = windower_player.id
    initialize()
    coroutine.sleep(2)
  end
end)

windower.register_event('login', function()
  local windower_player = windower.ffxi.get_player()
  if windower_player ~= nil then
    windower.send_command('lua load xivhotbar2')

    defaults = require('defaults')
    defaults.Keybinds = keyboard.default_keybinds
    settings = config.load(defaults)
    keyboard:cast_all_to_strings(settings)
    config.save(settings)

    -- Load theme options according to settings --
    theme = require('theme')
    theme_options = theme.apply(settings)
    player.id = windower_player.id

    initialize()
  end
end)

windower.register_event('logout', function()
  settings = nil
  theme = nil
  theme_options = nil
  state = {
    ready = false,
    demo = false,
    inventory_ready = false,
    inventory_loading = false
  }
  loaded = false
  first_load_done = false

  skillchains:destroy()
  ui:destroy()
end)

windower.register_event('unload', function()
  settings = nil
  theme = nil
  theme_options = nil
  state = {
    ready = false,
    demo = false,
    inventory_ready = false,
    inventory_loading = false
  }
  loaded = false
  first_load_done = false

  skillchains:destroy()
  utility_gauges:teardown()
  ui:destroy()
end)

-- DARK ARTS / LIGHT ARTS / ADD:BLK / ADD:WHT  set "stance"
windower.register_event('action', function(act)
  if state.ready == true then
    if (act.param == 211 or act.param == 212 or act.param == 234 or act.param == 235) then
      if (act.actor_id == player.id and act.category == 0x06) then
        player:load_job_ability_actions(act.param)
        ui:load_player_hotbar(player:get_hotbar_info())
      end
    end
    -- Feed gauges for SCH charge tracking and COR roll-number capture
    utility_gauges:on_action(act)
  end
end)

-- World is loaded or zoning
windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
  local seq = original:unpack('H', 3)

  if (next_sequence and seq >= next_sequence) and loaded then
    next_sequence = nil
    first_load_done = true
    on_world_load()
  end

  if id == 0x00B then -- unload old zone
    --print("dezone")
    loaded = false
    ui.hotbar.hide_hotbars = true
    ui:hide()
  elseif id == 0x00A then -- load new zone
    --print("begin load")
    loaded = false
    zoning = true
  elseif id == 0x01D and not loaded then
    --print("complete load")
    loaded = true
    zoning = false

    if first_load_done == false then
      -- first time load is significantly slower
      next_sequence = (seq + 18) % 0x10000
    else
      on_world_load()
    end
  end
end)

-- Equip / Unequip
windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
  if id == 0x050 then -- Equip/Unequip
    local packet = packets.parse('incoming', original)
    local slot = packet['Equipment Slot']

    -- slot 0 main, slot 2 ranged
    if slot == 0 or slot == 2 then
      local evt_inv_index = packet['Inventory Index']
      local evt_bag_index = packet['Inventory Bag']

      -- index > 0 means equipping
      if evt_inv_index ~= 0 then
        local weapon_changed = false
        local items = windower.ffxi.get_items()
        if slot == 0 then
          weapon_changed = set_weapon_type(false, evt_bag_index, items.equipment.main)
        elseif slot == 2 then
          weapon_changed = set_weapon_type(true, evt_bag_index, items.equipment.range)
        end

        if not zoning and weapon_changed then
          if ui.theme.dev_mode then log("Weapon Changed. Reloading Hotbar.") end
          reload_hotbar()
        end

        return
        -- index = 0 means unequipping
      else
        local weapon_changed = false
        if slot == 0 then
          if player.current_weapon ~= 0 then
            player:update_weapon_type(0)
            weapon_changed = true
          end
        elseif slot == 2 then
          if player.current_range_weapon ~= 0 then
            player:update_range_weapon_type(0)
            weapon_changed = true
          end
        end

        if not zoning and weapon_changed then
          if ui.theme.dev_mode then log("Weapon Unequipped. Reloading Hotbar.") end
          reload_hotbar()
        end

        return
      end
    end
  end
end)

-- Returns whether or not the weapon type was changed
function set_weapon_type(is_ranged, bag, index)
  local item = resources.items[windower.ffxi.get_items(bag, index).id]

  if item ~= nil then
    local new_skill_type = item.skill

    if theme_options.enable_weapon_switching == true then
      if new_skill_type ~= nil then
        if is_ranged then
          if player.current_range_weapon ~= new_skill_type then
            player:update_range_weapon_type(new_skill_type)
            return true -- Weapon type was changed
          end
        else
          if player.current_weapon ~= new_skill_type then
            player:update_weapon_type(new_skill_type)
            return true -- Weapon type was changed
          end
        end
      end
    end
  end

  return false -- Weapon type was not changed
end

windower.register_event('add item', 'remove item', function(id, bag, index, count)
  if state.ready == true then
    ui:update_inventory_count()
    player:update_inventory_items()
  end
end)

-- Updates on job change (moogle) and waits for abilities to be updated.
windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
  if state.ready == true then
    if id == 0x0AC and changing_job == true then
      changing_job = false
      if old_main ~= new_main or old_sub ~= new_sub then
        player:update_job(new_main, resources.jobs[new_main].ens, new_sub, resources.jobs[new_sub].ens)
        if ui.theme.dev_mode then log("Changing Job (Moogle)") end
        reload_hotbar()
      end
    elseif id == 0x01B then
      local windower_player = windower.ffxi.get_player()
      old_main = windower_player.main_job_id
      old_sub = windower_player.sub_job_id
      local packet = packets.parse('incoming', original)
      new_main = packet['Main Job']
      new_sub = packet['Sub Job']

      changing_job = true
    end
  end
end)

-- Updates on blu spell setting
windower.register_event('outgoing chunk', function(id, original, modified, injected, blocked)
  if id == 0x102 then
    if player.main_job_id == 16 or player.sub_job_id == 16 then
      if ui.theme.dev_mode then log("Set blue magic. Reloading Hotbar.") end
      -- takes time after setting blu magic for abilities to drop off
      coroutine.sleep(1.5)
      reload_hotbar()
    end
  end
end)

-- helper function for packet debugging
local function byte_to_binary(byte)
  local binary = {}
  for i = 7, 0, -1 do
    table.insert(binary, math.floor(byte / (2 ^ i)) % 2)
  end
  return table.concat(binary)
end

-- Updates on blu spell list
windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
  if id == 0x044 then
    if player.main_job_id == 16 or player.sub_job_id == 16 then
      local packet = packets.parse('incoming', original)
      if packet['Job'] == 16 then
        -- Iterate over each character in the string and convert to binary
        local binary_dump = {}
        local set_blu_spells = {}

        -- blu spells live in the region 0x08 through 0x1B
        -- (or decimal 8 through 27)
        for i = 9, 28 do
          local byte = string.byte(original, i)
          --table.insert(binary_dump, byte_to_binary(byte)) -- debugging
          if byte ~= 0x0 then
            table.insert(set_blu_spells, string.byte(original, i) + 512)
          end
          -- Add a line break every 8 bytes
          if i % 4 == 0 then
            table.insert(binary_dump, "\n")
          end
        end
        -- print("  " .. table.concat(binary_dump, "  "))  -- debugging, dump binary
        -- print(table.concat(set_blu_spells, "  ")) -- debugging, dump blu spells
        player:update_blue_magic(set_blu_spells)
      end
    end
  end
end)

-- Reloads hotbar if new weaponskill is learned.
windower.register_event('action message', function(actor_id, target_id, actor_index, target_index, message_id)
  if message_id == 45 then
    if actor_id == player.id then
      if ui.theme.dev_mode then log("Learned Weaponskill. Reloading Hotbar.") end
      reload_hotbar()
    end
  end
end)

-- Reloads hotbar if new spell is learned.
windower.register_event('action message', function(actor_id, target_id, actor_index, target_index, message_id)
  if message_id == 23 then
    if actor_id == player.id then
      if ui.theme.dev_mode then log("Learned Spell. Reloading Hotbar.") end
      reload_hotbar()
    end
  end
end)

-- Reloads hotbar when gaining or losing specified buffs
windower.register_event('gain buff', function(id)
  if id == 143 or id == 269 then -- Level Cap / Level Sync, Status Effect
    if ui.theme.dev_mode then log("Level Capped/Sync'd. Reloading Hotbar.") end
    reload_hotbar()
  elseif id == 55 then                                         -- Astral Flow - Status Effect
    reload_hotbar()
  elseif id == 377 then                                        -- Tabula Rasa- Status Effect
    reload_hotbar()
  elseif id == 359 or id == 402 or id == 358 or id == 401 then -- Dark Arts/Add Black/White Arts/Add White for stratagems
    reload_hotbar()
  elseif (id >= 381 and id <= 385) or id == 588 then           -- finishing move 1/2/3/4/5/6+
    player:sync_finishing_moves()                              -- re-derive from live buffs (handles upgrades correctly)
  elseif id == 47 or id == 360 or id == 361 or id == 229 or id == 583 then
    -- manafont, penury, parsimony, manawell, apogee
    player:add_buff(id)
    ui:update_mp_costs(player:get_hotbar_info())
  elseif id == 376 or id == 408 then
    -- trance, sekkanoki
    player:add_buff(id)
    ui:update_tp_costs(player:get_hotbar_info())
  end
  utility_gauges:on_buff_change()
end)

windower.register_event('lose buff', function(id)
  if id == 269 then -- Level Cap / Level Sync - Status Effect
    log("Leve Sync'd Removed. Reloading Hotbar.")
    reload_hotbar()
  elseif id == 55 then                                         -- Astral Flow - Status Effect
    reload_hotbar()
  elseif id == 377 then                                        -- Tabula Rasa - Status Effect
    reload_hotbar()
  elseif id == 359 or id == 402 or id == 358 or id == 401 then -- Dark Arts/Add Black/White Arts/Add White
    reload_hotbar()
  elseif (id >= 381 and id <= 385) or id == 588 then           -- finishing move 1/2/3/4/5/6+
    player:sync_finishing_moves()                              -- re-derive from live buffs (handles decrements correctly)
  elseif id == 47 or id == 360 or id == 361 or id == 229 or id == 583 then
    -- manafont, penury, parsimony, manawell, apogee
    player:remove_buff(id)
    ui:update_mp_costs(player:get_hotbar_info())
  elseif id == 376 or id == 408 then
    -- trance, sekkanoki
    player:remove_buff(id)
    ui:update_tp_costs(player:get_hotbar_info())
  end
  utility_gauges:on_buff_change()
end)

-- This event updates hotbar when you level up or delevel
windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
  if id == 0x02D then -- Kill Message
    mob_killed = true
    old_level = player.main_job_level
  elseif mob_killed and id == 0x061 then -- Mob Killed and Char Stats Message
    local packet = packets.parse('incoming', original)
    --print("Packet: ", packet)
    new_level = packet['Main Job Level']

    S { 'ws' }:contains('ws')
    if new_level ~= old_level then
      if ui.theme.dev_mode then log("Leveled up! Reloading Hotbar.") end
      reload_hotbar()
    end

    mob_killed = false
  end
end)






----------------------------- PET EVENT STUFF ----------------------------------------------------

--This event is reloading hotbar if a pet dies or released
windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
  local packet = packets.parse('incoming', original)
  if id == 0x068 then                       -- Pet Status Packet Update
    if packet['Owner ID'] == player.id then -- If player.id and pet owner ID are the same
      if packet['Pet Index'] == 0 then      -- If there is no pet. Meaning it died or was released.
        if ui.theme.dev_mode then log("Pet Died or was Released. Reloading Hotbar.") end
        -- takes time after a pet dies for its abilities to drop off
        coroutine.sleep(2.5)
        reload_hotbar('')
      end
    end
  end
end)

--This event is confirming that pet summons cast are not cancel/interupted and pet was succesfully summoned before updating the hotbar with specific pet abilities
windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
  if state.ready == true then
    local packet = packets.parse('incoming', original)
    if id == 0x068 then                                           -- If the second pet update packet comes in
      if packet['Owner ID'] == windower.ffxi.get_player().id then -- If player.id and pet owner ID are the same
        if packet['Pet Index'] ~= 0 then                          -- If the pet has an index of non zero then pet summoned succesfully
          if player.pet_name ~= packet['Pet Name'] then
            if ui.theme.dev_mode then log("Pet Summoned/Changed " .. packet['Pet Name'] .. ". Reloading Hotbar.") end
            reload_hotbar(packet['Pet Name'])
          end
        end
      end
    end
  end
end)

--Pet status update
windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
  if state.ready == true then
    local packet = packets.parse('incoming', original)
    if id == 0x068 then
      if packet['Owner ID'] == windower.ffxi.get_player().id then
        ui:update_pet_tp(packet['Pet TP'])
        ui:update_pet_mp(packet['Current MP%'])
      end
    end
  end
end)

windower.register_event('incoming text', function(text)
  if string.find(text, windower.ffxi.get_player().name) and string.find(text, " learns a new spell") then
    if ui.theme.dev_mode then log("Learned a new spell. Reloading Hotbar.") end
    reload_hotbar()
  end
end)

--- Reloads hotbar when using GM command. ** For development only **
windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
  if ui.theme.dev_mode then
    if id == 0x0AC and gm_command == true then
      if ui.theme.dev_mode then log("GM Command. Reloading Hotbar.", count) end
      gm_command = false
      reload_hotbar()
    end
  end
end)

windower.register_event('incoming text', function(text)
  if ui.theme.dev_mode then
    if string.find(text, "!changejob") or string.find(text, "!changesjob") then
      gm_command = true
    end
  end
end)



--- HELPERS
function printTable(tbl, indent)
  indent = indent or 0
  local indentString = string.rep("  ", indent)

  for key, value in pairs(tbl) do
    if type(value) == "table" then
      windower.add_to_chat(8, indentString .. tostring(key) .. ":")
      printTable(value, indent + 1)
    else
      windower.add_to_chat(8, indentString .. tostring(key) .. ": " .. tostring(value))
    end
  end
end

function shorten_ability_name(name)
  local function shortenWord(word)
    local result = ""
    local vowelPreserved = false

    for char in word:gmatch(".") do
      if #result < 3 then
        if char:match("[aeiouAEIOU]") then
          if not vowelPreserved then
            result = result .. char -- Keep the first vowel
            vowelPreserved = true
          end
        else
          result = result .. char -- Always keep consonants
        end
      else
        break -- Stop once we hit 4 characters
      end
    end

    return result
  end

  -- Process each word and combine them into camelCase
  local shortenedName = name:gsub("(%a)([%a]*)", function(firstLetter, restOfWord)
    return firstLetter:upper() .. shortenWord(restOfWord)
  end):gsub("%s+", "") -- Remove spaces to form camelCase

  -- Trim the overall name if it's still too long
  return shortenedName:sub(1, 6)
end
