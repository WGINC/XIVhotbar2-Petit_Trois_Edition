--[[
        Copyright © 2020, Akirane, Technyze
        All rights reserved.

        Redistribution and use in source and binary forms, with or without
        modification, are permitted provided that the following conditions are met:

            * Redistributions of source code must retain the above copyright
              notice, this list of conditions and the following disclaimer.
            * Redistributions in binary form must reproduce the above copyright
              notice, this list of conditions and the following disclaimer in the
              documentation and/or other materials provided with the distribution.
            * Neither the name of xivhotbar nor the
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

local file_manager = {}
files = require('files')

local current_job_file_path = ""
local current_general_file_path = ""

-- Debug logging: gated on the addon's existing dev_mode flag (//htb debug),
-- shared globally with ui.lua/action_manager.lua since none of these modules
-- use setfenv and therefore all see the same Lua globals.
local function dbg(msg)
  if ui and ui.theme and ui.theme.dev_mode then
    log('[FM] ' .. msg)
  end
end

local function basename(path)
  return path and path:match('([^/\\]+)$') or tostring(path)
end


local function fill_table(file)
  file_content = {}
  for line in file:lines() do
    table.insert(file_content, line)
  end
  return file_content
end

-- Position-only removal: deletes whatever row is at row/slot regardless of what (if anything)
-- it actually is. Unlike find_in_file_remove, this doesn't need to know the action's name --
-- it's for //htb clear, which should scrub a slot even when memory has nothing recorded there
-- (e.g. the row's action failed action_req_check and was never loaded, so there's no in-memory
-- action object to match a name against).
local function find_in_file_clear(file_path, row, slot, environment)
  local env_long, env_short
  if environment == 'b' or environment == 'battle' then
    env_short, env_long = 'b', 'battle'
  elseif environment == 'f' or environment == 'field' then
    env_short, env_long = 'f', 'field'
  else
    env_short, env_long = environment, environment
  end

  local row_to_find_long  = string.format('%s %d %d', env_long,  row, slot)
  local row_to_find_short = string.format('%s %d %d', env_short, row, slot)
  local found_row = false
  local fileContent = {}
  local file = io.open(file_path, 'r')

  dbg(string.format('clear_slot: looking for any row matching "%s" / "%s" in %s',
    row_to_find_long, row_to_find_short, basename(file_path)))

  if (file ~= nil) then
    for line in file:lines() do
      table.insert(fileContent, line)
    end
    for key, val in pairs(fileContent) do
      if val:contains(row_to_find_long) or val:contains(row_to_find_short) then
        found_row = true
        dbg(string.format('clear_slot: MATCHED and removed line: %s', val))
        fileContent[key] = '0'
        break
      end
    end
    if (found_row == true) then
      file = io.open(file_path, 'w')
      for index, value in ipairs(fileContent) do
        if (value ~= '0') then
          file:write(value .. '\n')
        end
      end
      io.close(file)
    else
      dbg(string.format('clear_slot: no row matching "%s"/"%s" found in %s', row_to_find_long, row_to_find_short, basename(file_path)))
    end
  else
    dbg(string.format('clear_slot: could not open %s for reading', basename(file_path)))
  end
  return found_row
end

local function find_in_file_remove(file_path, action, row, slot, environment)
  local testAc = action.action:lower()

  local env_long, env_short
  if environment == 'b' or environment == 'battle' then
    env_short, env_long = 'b', 'battle'
  elseif environment == 'f' or environment == 'field' then
    env_short, env_long = 'f', 'field'
  else
    env_short, env_long = environment, environment
  end

  local row_to_find_long  = string.format('%s %d %d', env_long,  row, slot)
  local row_to_find_short = string.format('%s %d %d', env_short, row, slot)
  local found_row = false
  local fileContent = {}
  local file = io.open(file_path, 'r')

  dbg(string.format('write_remove: looking for "%s" / "%s" (action="%s") in %s',
    row_to_find_long, row_to_find_short, action.action, basename(file_path)))

  if (file ~= nil) then
    for line in file:lines() do
      table.insert(fileContent, line)
    end
    for key, val in pairs(fileContent) do
      local row_to_find
      if val:contains(row_to_find_long) then
        row_to_find = row_to_find_long
      elseif val:contains(row_to_find_short) then
        row_to_find = row_to_find_short
      end

      if row_to_find then
        if (val:lower():contains(testAc)) then
          found_row = true
          dbg(string.format('write_remove: MATCHED and removed line: %s', val))
          if (debug == true) then
            print("[file_manager:find_in_file_remove] val:lower():contains(testAc) succeeded")
            print(val)
          end
          fileContent[key] = '0'
          break
        elseif (val:contains("'gs'")) then
          local stripped_row = val:lower()
          i, j = string.find(stripped_row, '%[.*%]')
          k, l = string.find(testAc, '%[.*%]')
          local sub_row = string.sub(stripped_row, i + 3, j - 3)
          local sub_ac = string.sub(testAc, k + 2, l - 2)
          if sub_row == sub_ac then
            if (debug == true) then
              print("[file_manager:find_in_file_remove] sub_row == sub_ac succeeded")
              print(val)
            end
            found_row = true
            dbg(string.format('write_remove: MATCHED (gearswap) and removed line: %s', val))
            fileContent[key] = '0'
            break
          end
        else
          dbg(string.format('write_remove: row position matched but action name "%s" not found in line: %s', testAc, val))
        end
      end
    end
    if (found_row == true) then
      file = io.open(file_path, 'w')
      for index, value in ipairs(fileContent) do
        if (value ~= '0') then
          file:write(value .. '\n')
        end
      end
      io.close(file)
    else
      dbg(string.format('write_remove: FAILED to find a matching row for "%s"/"%s" with action "%s" in %s -- old entry (if any) was NOT removed',
        row_to_find_long, row_to_find_short, action.action, basename(file_path)))
    end
  else
    dbg(string.format('write_remove: could not open %s for reading', basename(file_path)))
  end
  return found_row
end

local function write_swap(file_location, action, d_row, d_slot, s_row, s_slot, environment)
  -- Normalize: produce both the long form ('battle'/'field') used in player-authored files
  -- and the short form ('b'/'f') used by insert_action, so we handle either on disk.
  local env_long, env_short
  if environment == 'b' or environment == 'battle' then
    env_short, env_long = 'b', 'battle'
  elseif environment == 'f' or environment == 'field' then
    env_short, env_long = 'f', 'field'
  else
    env_short, env_long = environment, environment
  end

  local testAc            = action.action:lower()
  local row_to_find_long  = string.format('%s %d %d', env_long,  s_row, s_slot)
  local row_to_find_short = string.format('%s %d %d', env_short, s_row, s_slot)
  local new_row_long      = string.format('%s %d %d', env_long,  d_row, d_slot)
  local new_row_short     = string.format('%s %d %d', env_short, d_row, d_slot)
  local found_row = false
  local fileContent = {}
  local file = io.open(file_location, 'r')

  if (file ~= nil) then
    for line in file:lines() do
      table.insert(fileContent, line)
    end
    for key, val in pairs(fileContent) do
      -- Detect which format this line uses and pick the matching replacement string
      local row_to_find, new_row
      if val:contains(row_to_find_long) then
        row_to_find, new_row = row_to_find_long, new_row_long
      elseif val:contains(row_to_find_short) then
        row_to_find, new_row = row_to_find_short, new_row_short
      end

      if row_to_find then
        if (debug == true) then
          print("Found the row")
        end
        if (val:lower():contains(testAc)) then
          found_row = true
          -- Replace the exact matched token (avoids the old regex corrupting 'battle' → 'battlX Y Z')
          fileContent[key] = val:gsub(row_to_find, new_row, 1)
          if (debug == true) then
            print("val:lower():contains(testAc) succeeded")
            print(fileContent[key])
          end
          break
        elseif string.find(val, "'%f[%a]gs%f[%A]'") and string.find(val, 'equip') then
          local stripped_row = val:lower()
          print("This is a gearswap row.")
          print(val)
          i, j = string.find(stripped_row, '%[.*%]')
          k, l = string.find(testAc, '%[.*%]')
          local sub_row = string.sub(stripped_row, i + 3, j - 3)
          local sub_ac = string.sub(testAc, k + 2, l - 2)
          if sub_row == sub_ac then
            found_row = true
            fileContent[key] = val:gsub(row_to_find, new_row, 1)
            if (debug == true) then
              print("sub_row == sub_ac succeeded")
              print(fileContent[key])
            end
            break
          end
        end
      end
    end
    if (found_row == true) then
      file = io.open(file_location, 'w')
      for index, value in ipairs(fileContent) do
        file:write(value .. '\n')
      end
      io.close(file)
    else
      dbg(string.format('write_swap: no row matching "%s"/"%s" with action "%s" found in %s',
        row_to_find_long, row_to_find_short, action.action, basename(file_location)))
    end
  end
  return found_row
end


function file_manager:update_file_path(player_name, player_job)
  local basepath = windower.addon_path .. 'data/' .. player_name .. '/'
  local job_name = player_job
  current_job_file_path = basepath .. job_name .. '.lua'
  current_general_file_path = basepath .. "General.lua"
end

local function find_in_file(file_content, action, environment, pattern)
  local pattern_start    = 0
  local pattern_end      = 0
  local found_pattern_start = false
  local found_pattern_end   = false
  local found_in_section    = false

  if (type(file_content) == "table") then
    for key, val in pairs(file_content) do
      local i, j = string.find(val, pattern)
      if (i ~= nil and j ~= nil) then
        found_pattern_start = true
        pattern_start = key + 1
      end
      -- '^}' required the brace to be the literal first character of the line, so a closing
      -- brace with any leading whitespace/indentation (e.g. " }") was invisible to this search.
      -- That let the section boundary blow straight through the real end of the table and
      -- into whatever table came next in the file, silently writing into the wrong job/subjob
      -- table entirely while still reporting success. '^%s*}' tolerates leading whitespace
      -- while still correctly rejecting normal row lines (which start with '{', not whitespace+'}').
      local k, l = string.find(val, '^%s*}')
      if (k ~= nil and l ~= nil and found_pattern_start == true) then
        pattern_end = key - 1
        found_pattern_end = true
        break
      end
    end
    if (found_pattern_end == false) then
      dbg(string.format('insert: could not find section matching pattern "%s" -- nothing written', pattern))
      found_in_section = true -- nothing to write; tell the caller this was NOT a successful insert
    else
      local existing_index = nil
      for i = pattern_start, pattern_end do
        local k, j = string.find(file_content[i], '\'')
        if (k ~= nil and j ~= nil) then
          local found_row = string.match(file_content[i], environment)
          if (found_row ~= nil) then
            found_in_section = true
            existing_index = i
            break
          end
        end
      end
      new_row = "\t{'" ..
      environment ..
      "', '" .. action.type .. "', \"" .. action.action .. "\", '" .. action.target .. "', \"" .. action.alias .. "\"},"
      if (found_in_section == false) then
        table.insert(file_content, pattern_end + 1, new_row)
        dbg(string.format('insert: section "%s" had no existing row for "%s" -- wrote new row: %s',
          pattern, environment, new_row))
      else
        -- A row already exists for this position. Overwrite it instead of skipping the write.
        -- This is the case where the old action there didn't pass action_req_check (wrong job,
        -- not learned, etc.) so it never made it into the in-memory hotbar table -- the slot
        -- looked empty to the caller, but the stale text was still here blocking a fresh insert.
        -- Replacing it in place makes this self-healing instead of a silent dead end.
        dbg(string.format('insert: section "%s" had a STALE row for "%s" (old: %s) -- REPLACING it with: %s',
          pattern, environment, file_content[existing_index], new_row))
        file_content[existing_index] = new_row
        found_in_section = false -- tell the caller a write happened so it actually saves the file
      end
    end
  end
  return found_in_section
end

local function write_to_file(file_path, new_file_content)
  file = io.open(file_path, 'w')
  for index, value in ipairs(new_file_content) do
    file:write(value .. '\n')
  end
  io.close(file)
end

function file_manager:insert_action(action, prio, player_subjob, environment, row, slot)
  local row_to_find = string.format('%s %d %d', environment, row, slot)
  local fileContent = {}
  local found = false
  local file = {}
  local file_to_open = ""

  if (prio == 'g') then
    file_to_open = current_general_file_path
  else
    file_to_open = current_job_file_path
  end
  dbg(string.format('insert_action: prio=%s row_to_find="%s" action="%s" target="%s" file=%s',
    prio, row_to_find, action.action, tostring(action.target), basename(file_to_open)))
  file = io.open(file_to_open, 'r')
  if (file ~= nil) then
    fileContent = fill_table(file)
    io.close(file)
    if (prio == 'm') then
      found = find_in_file(fileContent, action, row_to_find, 'xivhotbar_keybinds_job%[\'Base\'%]')
    elseif (prio == 's') then
      found = find_in_file(fileContent, action, row_to_find, 'xivhotbar_keybinds_job%[\'' .. player_subjob .. '\'%]')
    elseif (prio == 'g') then
      found = find_in_file(fileContent, action, row_to_find, 'xivhotbar_keybinds_general%[\'Root\'%]')
    end
    if (found == false) then
      write_to_file(file_to_open, fileContent)
      dbg(string.format('insert_action: SUCCESS -- wrote "%s" to %s', action.action, basename(file_to_open)))
      return true
    else
      dbg(string.format('insert_action: FAILED -- could not find section for "%s" in %s, "%s" was NOT written',
        row_to_find, basename(file_to_open), action.action))
      return false
    end
  else
    dbg(string.format('insert_action: FAILED -- could not open %s for reading', basename(file_to_open)))
    return false
  end
end

function file_manager:write_changes(action, d_row, d_slot, s_row, s_slot, environment)
  local found_row = write_swap(current_job_file_path, action, d_row, d_slot, s_row, s_slot, environment)

  if (found_row == false) then
    found_row = write_swap(current_general_file_path, action, d_row, d_slot, s_row, s_slot, environment)
  end
  dbg(string.format('write_changes: %s for "%s" (%s %d %d -> %d %d)',
    found_row and 'SUCCESS' or 'FAILED -- no matching row found in either file',
    action.action, environment, s_row, s_slot, d_row, d_slot))
  return found_row
end

function file_manager:write_remove(action, row, slot, environment)
  local found_row = find_in_file_remove(current_job_file_path, action, row, slot, environment)

  if (found_row == false) then
    found_row = find_in_file_remove(current_general_file_path, action, row, slot, environment)
  end
  dbg(string.format('write_remove: %s removing "%s" at %s %d %d',
    found_row and 'SUCCESS' or 'FAILED -- no matching row found in either file',
    action.action, environment, row, slot))
  return found_row
end

-- Used by //htb clear (and its alias //htb delete). Scrubs by position alone, in both
-- the job file and General.lua, regardless of whether memory thinks the slot is occupied.
function file_manager:clear_slot(row, slot, environment)
  local found_row = find_in_file_clear(current_job_file_path, row, slot, environment)

  if (found_row == false) then
    found_row = find_in_file_clear(current_general_file_path, row, slot, environment)
  end
  dbg(string.format('clear_slot: %s at %s %d %d',
    found_row and 'SUCCESS' or 'nothing found to remove in either file', environment, row, slot))
  return found_row
end

return file_manager
