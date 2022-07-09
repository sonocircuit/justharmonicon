-- justharmonicon
--
-- a subharmonic sequencer
-- for norns and just friends
--
-- 1.0.1 @sonocircuit
-- llllllll.co/t/?????
--
--
-- for docs go to:
-- >> github.com/sonocircuits
--    /justharmonicon
--
-- or smb into:
-- >> code/justharmonicon/docs
--
--

halfsync = include('lib/halfsync')

mu = require "musicutil"

-------- variables --------

local shift = false
local pageNum = 1
local n_edit = 1
local r_edit = 1
local o_edit = 1
local run = false

-------- tables --------

options = {}
options.pages = {"SEQUENCERS", "POLYRHYTHM", "OSCILLATORS"}
options.scale_names = {"12ET", "8ET", "12JI", "8JI"}
options.binary = {"no", "yes"}
options.assign_voice = {">>>>>>", "<<<>>>", ">>><<<", "<<<<<<"}
options.clk_div = {1, 2, 4, 8}

midi_devices = {}

scale_notes = {}
scale_notes[1] = {0, 1/12, 2/12, 3/12, 4/12, 5/12, 6/12, 7/12, 8/12, 9/12, 10/12, 11/12, 12/12, 13/12, 14/12, 15/12, 16/12, 17/12, 18/12, 19/12, 20/12, 21/12, 22/12, 23/12, 24/12} -- 12ET scale
scale_notes[2] = {4/12, 5/12, 7/12, 9/12, 11/12, 12/12, 14/12, 16/12, 17/12, 19/12, 21/12, 23/12, 24/12, 26/12, 28/12, 29/12, 31/12, 33/12, 35/12, 36/12, 38/12, 40/12, 41/12, 43/12, 45/12} -- 8ET scale
scale_notes[3] = {1/1, 16/15, 9/8, 6/5, 5/4, 4/3, 45/32, 3/2, 8/5, 5/3, 16/9, 15/8, 2/1, 32/15, 18/8, 12/5, 10/4, 8/3, 90/32, 6/2, 16/5, 10/3, 32/9, 30/8, 4/1} -- 12JI scale
scale_notes[4] = {5/4, 4/3, 3/2, 5/3, 15/8, 2/1, 18/8, 10/4, 8/3, 6/2, 10/3, 30/8, 4/1, 36/8, 20/4, 16/3, 12/2, 20/3, 60/8, 8/1, 72/8, 40/4, 32/3, 24/2, 40/3} -- 8JI scale

pattern = {}
pattern.oct = {0, 0, 1, 0}
pattern.notes = {}
for i = 1, 2 do -- 2 sequences
  pattern.notes[i] = {}
  for j = 1, 4 do -- 4 notes each
    table.insert(pattern.notes[i], j, math.random(1, 25)) -- +/- 12 note steps
  end
end

rytm = {}
rytm.clk_div = 1
for i = 1, 4 do
  rytm[i] = {}
  rytm[i].rate = 1
  rytm[i].step = false
  rytm[i].seq_one = false
  rytm[i].seq_two = false
  rytm[i].seq_oct = false
end

seq = {}
seq.oct_step = false
seq.oct_pos = 1
for i = 1, 2 do
  seq[i] = {}
  seq[i].step = false
  seq[i].pos = 1
  seq[i].root = 0
  seq[i].sub1 = 1
  seq[i].sub2 = 1
end

set_crow = {}
for i = 1, 6 do -- 6 voices
  set_crow[i] = {}
  set_crow[i].jf_ch = i
  set_crow[i].jf_amp = 5
end

set_env = {}
for i = 1, 4 do -- 4 env
  set_env[i] = {}
  set_env[i].active = false
  set_env[i].amp = 8
  set_env[i].a = 0
  set_env[i].a = 0.4
end


-------- seq settings --------

function set_voice()
  if params:get("voice_allocation") == 1 then
    for i = 1, 6 do
      set_crow[i].jf_ch = i
    end
  elseif params:get("voice_allocation") == 2 then
    set_crow[1].jf_ch = 3
    set_crow[2].jf_ch = 4
    set_crow[3].jf_ch = 2
    set_crow[4].jf_ch = 5
    set_crow[5].jf_ch = 1
    set_crow[6].jf_ch = 6
  elseif params:get("voice_allocation") == 3 then
    set_crow[1].jf_ch = 1
    set_crow[2].jf_ch = 6
    set_crow[3].jf_ch = 2
    set_crow[4].jf_ch = 5
    set_crow[5].jf_ch = 3
    set_crow[6].jf_ch = 4
  else
    set_crow[1].jf_ch = 6
    set_crow[2].jf_ch = 5
    set_crow[3].jf_ch = 4
    set_crow[4].jf_ch = 3
    set_crow[5].jf_ch = 2
    set_crow[6].jf_ch = 1
  end
  -- remap levels
  for i = 1, 2 do
    set_crow[set_crow[i].jf_ch].jf_amp = util.linlin(0, 10, 0, 5, params:get("level_osc"..i))
    set_crow[set_crow[i + 2].jf_ch].jf_amp = util.linlin(0, 10, 0, 5, params:get("level_sub1"..i))
    set_crow[set_crow[i + 4].jf_ch].jf_amp = util.linlin(0, 10, 0, 5, params:get("level_sub2"..i))
  end
end

function set_rate()
  for i = 1, 4 do
    rytm[i].rate = params:get("rytm_div"..i) / (4 / rytm.clk_div)
  end
end

function reset_pos()
  for i = 1, 2 do
    seq[i].pos = 1
  end
  seq.oct_pos = 1
end

-------- scale settings --------

-- convert JI intervals to CV
function ji_calc(interval)
  local volt = math.log(interval) / math.log(2) -- log2(interval)
  return volt
end

-- convert freq divisons to CV
function div_calc(div)
  local volt = (-1 / math.log(2)) * math.log(div) -- -1 / math.log(2) = -1.4427 == log2 of e
  return volt -- cv to subtract from the note cv (1v/oct assumed)
end

-------- midi --------

function build_midi_device_list()
  midi_devices = {}
  for i = 1, #midi.vports do
    local long_name = midi.vports[i].name
    local short_name = string.len(long_name) > 15 and util.acronym(long_name) or long_name
    table.insert(midi_devices, i..": "..short_name)
  end
end

function midi.add() -- MIDI register callback
  build_midi_device_list()
end

function midi.remove() -- MIDI remove callback
  clock.run(
    function()
      clock.sleep(0.2)
      build_midi_device_list()
    end
  )
end

function clock.transport.start()
  if params:get("midi_trnsp") == 3 then
    run = true
  end
end

function clock.transport.stop()
  if params:get("midi_trnsp") == 3 then
    run = false
    reset_pos()
  end
  dirtyscreen = true
end


-------- defaults and presets --------

function set_defaults()
  params:set("rytm_to_seq1"..1, 2)
  params:set("rytm_to_seq1"..2, 1)
  params:set("rytm_to_seq1"..3, 2)
  params:set("rytm_to_seq1"..4, 2)

  params:set("rytm_to_seq2"..1, 1)
  params:set("rytm_to_seq2"..2, 2)
  params:set("rytm_to_seq2"..3, 1)
  params:set("rytm_to_seq2"..4, 1)

  params:set("rytm_to_oct"..1, 1)
  params:set("rytm_to_oct"..2, 1)
  params:set("rytm_to_oct"..3, 2)
  params:set("rytm_to_oct"..4, 1)

  params:set("rytm_div"..1, 7)
  params:set("rytm_div"..2, 6)
  params:set("rytm_div"..3, 7)
  params:set("rytm_div"..4, 13)

end

-------- init function --------
function init()

  params:add_separator("global settings")

  -- set scale
  params:add_option("scale_mode", "scale", options.scale_names, 1)

  params:add_option("clk_division", "clock div", options.clk_div, 1)
  params:set_action("clk_division", function(div) rytm.clk_div = div set_rate() end)

  params:add_option("voice_allocation", "voice allocation", options.assign_voice, 1)
  params:set_action("voice_allocation", function() set_voice() end)

  params:add_trigger("connect_jf", "reconnect jf")
  params:set_action("connect_jf", function() crow.ii.jf.mode(1) end)

  build_midi_device_list()

  params:add_option("midi_device", "midi device", midi_devices, 1)
  params:set_action("midi_device", function(val) m = midi.connect(val) end)

  params:add_option("midi_trnsp", "midi transport", {"off", "send", "receive"}, 1)

  params:add_separator("oscillators")

  for i = 1, 2 do
    params:add_group("oscillator "..i, 13)

    params:add_separator("sequence "..i)

    params:add_option("osc_assign"..i, "sequence osc", options.binary, 2)
    params:set_action("osc_assign"..i, function() sup(1) end)

    params:add_option("sub1_assign"..i, "sequence sub1", options.binary, 1)
    params:set_action("sub1_assign"..i, function() sup(1) end)

    params:add_option("sub2_assign"..i, "sequence sub2", options.binary, 1)
    params:set_action("sub2_assign"..i, function() sup(1) end)

    params:add_option("oct_assign"..i, "add octaves", options.binary, 2)
    params:set_action("oct_assign"..i, function() sup(1) end)

    params:add_separator("tuning")

    params:add_number("freq_osc"..i, "osc"..i.." tuning", 24, 84, 60, function(param) return mu.note_num_to_name(param:get(), true) end)
    params:set_action("freq_osc"..i, function(num) seq[i].root = num - 60 sup(3) end)

    params:add_number("freq_sub1"..i, "sub1 division", 1, 16, 1)
    params:set_action("freq_sub1"..i, function(val) seq[i].sub1 = val sup(3) end)

    params:add_number("freq_sub2"..i, "sub2 division", 1, 16, 1)
    params:set_action("freq_sub2"..i, function(val) seq[i].sub2 = val sup(3) end)

    params:add_separator("levels")

    params:add_control("level_osc"..i, "osc"..i.." level", controlspec.new(0.0, 10.0, "lin", 0.1, 10.0, ""))
    params:set_action("level_osc"..i, function(level) set_crow[set_crow[i].jf_ch].jf_amp = util.linlin(0, 10, 0, 5, level) end) -- 1, 2

    params:add_control("level_sub1"..i, "sub1 level", controlspec.new(0.0, 10.0, "lin", 0.1, 0.0, ""))
    params:set_action("level_sub1"..i, function(level) set_crow[set_crow[i + 2].jf_ch].jf_amp = util.linlin(0, 10, 0, 5, level) end) -- 3, 4

    params:add_control("level_sub2"..i, "sub2 level", controlspec.new(0.0, 10.0, "lin", 0.1, 0.0, ""))
    params:set_action("level_sub2"..i, function(level) set_crow[set_crow[i + 4].jf_ch].jf_amp = util.linlin(0, 10, 0, 5, level) end) -- 5, 6
  end

  params:add_separator("polyrhythm")

  for i = 1, 4 do
    params:add_group("rhythm "..i, 9)
    params:add_number("rytm_div"..i, "division", 1, 16, 1)
    params:set_action("rytm_div"..i, function(div) rytm[i].rate = div / (4 / rytm.clk_div) end)

    params:add_option("rytm_to_seq1"..i, "drive seq1", {"no", "yes"}, 1)
    params:set_action("rytm_to_seq1"..i, function(val) rytm[i].seq_one = val == 2 and true or false sup(2) end)

    params:add_option("rytm_to_seq2"..i, "drive seq2", {"no", "yes"}, 1)
    params:set_action("rytm_to_seq2"..i, function(val) rytm[i].seq_two = val == 2 and true or false sup(2) end)

    params:add_option("rytm_to_oct"..i, "drive oct seq", {"no", "yes"}, 1)
    params:set_action("rytm_to_oct"..i, function(val) rytm[i].seq_oct = val == 2 and true or false sup(2) end)

    params:add_separator("crow out "..i)

    params:add_option("crow_env"..i, "output active", options.binary, 1)
    params:set_action("crow_env"..i, function(val) set_env[i].active = val == 2 and true or false end)

    params:add_control("env_amp"..i, "env amplitude", controlspec.new(0.1, 10, "lin", 0.1, 5, "v"))
    params:set_action("env_amp"..i, function(val) set_env[i].amp = val end)

    params:add_control("env_attack"..i, "attack", controlspec.new(0.00, 1, "lin", 0.01, 0.00, "s"))
    params:set_action("env_attack"..i, function(val) set_env[i].a = val end)

    params:add_control("env_decay"..i, "decay", controlspec.new(0.01, 1, "lin", 0.01, 0.4, "s"))
    params:set_action("env_decay"..i, function(val) set_env[i].d = val end)
  end

  params:add_separator("fx")

  -- delay params
  params:add_group("delay", 8)
  halfsync.init()

  -- note patterns
  for i = 1, 4 do
    params:add_number("pattern_one"..i, "pattern one"..i, 1, 25, pattern.notes[1][i])
    params:set_action("pattern_one"..i, function(val) pattern.notes[1][i] = val sup(1) end)
    params:hide("pattern_one"..i)

    params:add_number("pattern_two"..i, "pattern two"..i, 1, 25, pattern.notes[2][i])
    params:set_action("pattern_two"..i, function(val) pattern.notes[2][i] = val sup(1) end)
    params:hide("pattern_two"..i)

    params:add_number("pattern_oct"..i, "pattern oct"..i, -3, 3, pattern.oct[i])
    params:set_action("pattern_oct"..i, function(val) pattern.oct[i] = val sup(1) end)
    params:hide("pattern_oct"..i)
  end

  params:bang()

  set_defaults()

  crow.ii.pullup(true)
  crow.ii.jf.mode(1)

  -- clocks
  for i = 1, 4 do
    clock.run(polyrytm, i)
  end

  clock.run(stepper)

  clock.run(screen_update)
  dirtyscreen = true

end

-------- sequencer --------

function polyrytm(i)
  while true do
    clock.sync(rytm[i].rate)
    if run then
      -- pulse screen
      if pageNum == 2 then
        clock.run(
          function()
            rytm[i].step = true
            dirtyscreen = true
            clock.sleep(1/15)
            rytm[i].step = false
            dirtyscreen = true
          end
        )
      end
      -- step logic
      if rytm[i].seq_one then
        clock.run(
          function()
            seq[1].step = true
            clock.sync(1/24)
            seq[1].step = false
          end
        )
      end
      if rytm[i].seq_two then
        clock.run(
          function()
            seq[2].step = true
            clock.sync(1/24)
            seq[2].step = false
          end
        )
      end
      if rytm[i].seq_oct then
        clock.run(
          function()
            seq.oct_step = true
            clock.sync(1/24)
            seq.oct_step = false
          end
        )
      end
      -- crow output
      if set_env[i].active then
        crow.output[i].action = "{ to(0, 0), to("..set_env[i].amp..", "..set_env[i].a.."), to(0, "..set_env[i].d..", 'log') }"
        crow.output[i]()
      end
    end
  end
end

function stepper()
  while true do
    clock.sync(1/8)
    for i = 1, 2 do
      if seq[i].step then
        seq[i].pos = seq[i].pos + 1
        if seq[i].pos > 4 then
          seq[i].pos = 1
        end
        play_voice(i)
      end
    end
    if seq.oct_step then
      seq.oct_pos = seq.oct_pos + 1
      if seq.oct_pos > 4 then
        seq.oct_pos = 1
      end
    end
    if pageNum == 1 then dirtyscreen = true end
  end
end

function play_voice(i)
  -- get cv from scale notes
  local note_volt
  if params:get("scale_mode") < 3 then
    note_volt = scale_notes[params:get("scale_mode")][pattern.notes[i][seq[i].pos]] - (params:get("scale_mode") == 1 and 1 or 2)
  else
    note_volt = ji_calc(scale_notes[params:get("scale_mode")][pattern.notes[i][seq[i].pos]]) - (params:get("scale_mode") == 3 and 1 or 2)
  end
  -- get cv for root note + octave
  local root_volt = (seq[i].root / 12) + (params:get("oct_assign"..i) == 2 and pattern.oct[seq.oct_pos] or 0)
  -- calc cv of played note
  local play_note
  if params:get("osc_assign"..i) == 1 then
    play_note = root_volt
  else
    play_note = root_volt + note_volt
  end
  -- play osc voice
  crow.ii.jf.play_voice(set_crow[i].jf_ch, play_note, set_crow[set_crow[i].jf_ch].jf_amp)
  -- calc and play sub1 voice
  if params:get("sub1_assign"..i) == 1 then
    crow.ii.jf.play_voice(set_crow[i + 2].jf_ch, play_note + div_calc(seq[i].sub1), set_crow[set_crow[i + 2].jf_ch].jf_amp)
  else
    local scaled_notes = math.floor(util.linlin(1, 25, -8, 8, pattern.notes[i][seq[i].pos]))
    local sub = util.clamp(seq[i].sub1 + scaled_notes, 1, 16)
    crow.ii.jf.play_voice(set_crow[i + 2].jf_ch, play_note + div_calc(sub), set_crow[set_crow[i + 2].jf_ch].jf_amp)
  end
  -- calc and play sub2 voice
  if params:get("sub2_assign"..i) == 1 then
    crow.ii.jf.play_voice(set_crow[i + 4].jf_ch, play_note + div_calc(seq[i].sub2), set_crow[set_crow[i + 4].jf_ch].jf_amp)
  else
    local scaled_notes = math.floor(util.linlin(1, 25, -8, 8, pattern.notes[i][seq[i].pos]))
    local sub = util.clamp(seq[i].sub2 + scaled_notes, 1, 16)
    crow.ii.jf.play_voice(set_crow[i + 4].jf_ch, play_note + div_calc(sub), set_crow[set_crow[i + 4].jf_ch].jf_amp)
  end
end

-------- norns interface --------

function key(n, z)
  if n == 1 then
    shift = z == 1 and true or false
  end
  if pageNum < 4 then -- currently all pages
    if n == 2 and z == 1 then
      if not shift then
        run = not run
      else
        play_voice(1)
      end
    elseif n == 3 and z == 1 then
      if not shift then
        reset_pos()
      else
        play_voice(2)
      end
    end
  else
    -- other page
  end
  dirtyscreen = true
end

function enc(n, d)
  if n == 1 then
    pageNum = util.clamp(pageNum + d, 1, #options.pages)
    dirtyscreen = true
  end
  if pageNum == 1 then
    if n == 2 then
      n_edit = util.clamp(n_edit + d, 1, 20)
    elseif n == 3 then
      if n_edit < 5 then
        params:delta("pattern_one"..n_edit, d)
      elseif n_edit > 4 and n_edit < 9 then
        params:delta("pattern_two"..n_edit - 4, d)
      elseif n_edit > 8 and n_edit < 13 then
        params:delta("pattern_oct"..n_edit - 8, d)
      elseif n_edit == 13 then
        params:delta("osc_assign"..1, d)
      elseif n_edit == 14 then
        params:delta("sub1_assign"..1, d)
      elseif n_edit == 15 then
        params:delta("sub2_assign"..1, d)
      elseif n_edit == 16 then
        params:delta("osc_assign"..2, d)
      elseif n_edit == 17 then
        params:delta("sub1_assign"..2, d)
      elseif n_edit == 18 then
        params:delta("sub2_assign"..2, d)
      elseif n_edit == 19 then
        params:delta("oct_assign"..1, d)
      elseif n_edit == 20 then
        params:delta("oct_assign"..2, d)
      end
    end
  elseif pageNum == 2 then
    if n == 2 then
      r_edit = util.clamp(r_edit + d, 1, 16)
    elseif n == 3 then
      if r_edit < 5 then
        params:delta("rytm_div"..r_edit, d)
      elseif r_edit > 4 and r_edit < 9 then
        params:delta("rytm_to_seq1"..r_edit - 4, d)
      elseif r_edit > 8 and r_edit < 13 then
        params:delta("rytm_to_seq2"..r_edit - 8, d)
      elseif r_edit > 12 then
        params:delta("rytm_to_oct"..r_edit - 12, d)
      end
    end
  elseif pageNum == 3 then
    if n == 2 then
      o_edit = util.clamp(o_edit + d, 1, 6)
    elseif n == 3 then
      if not shift then
        if o_edit == 1 then
          params:delta("freq_osc"..1, d)
        elseif o_edit == 2 then
          params:delta("freq_sub1"..1, d)
        elseif o_edit == 3 then
          params:delta("freq_sub2"..1, d)
        elseif o_edit == 4 then
          params:delta("freq_osc"..2, d)
        elseif o_edit == 5 then
          params:delta("freq_sub1"..2, d)
        else
          params:delta("freq_sub2"..2, d)
        end
      else
        if o_edit == 1 then
          params:delta("level_osc"..1, d)
        elseif o_edit == 2 then
          params:delta("level_sub1"..1, d)
        elseif o_edit == 3 then
          params:delta("level_sub2"..1, d)
        elseif o_edit == 4 then
          params:delta("level_osc"..2, d)
        elseif o_edit == 5 then
          params:delta("level_sub1"..2, d)
        else
          params:delta("level_sub2"..2, d)
        end
      end
    end
  end
  dirtyscreen = true
end

function redraw()
  screen.clear()
  for i = 1, #options.pages do
    screen.level(i == pageNum and 15 or 2)
    screen.rect(i * 8 + 92, 4, 4, 4)
    screen.fill()
  end
  screen.level(8)
  screen.move(9, 8)
  screen.text(options.pages[pageNum])

  if pageNum == 1 then
    -- draw sequencers
    for i = 1, 2 do
      for j = 1, 4 do
        -- note bars
        screen.line_width(6)
        screen.level((j == n_edit - ((i - 1) * 4)) and 6 or 1)
        screen.move(i * 46 - 46 + 9, j * 8 - 8 + 16)
        screen.line_rel(25, 0)
        screen.stroke()
        -- center indicator
        screen.level(0)
        screen.move(i * 46 - 46 + 21, j * 8 - 8 + 16)
        screen.line_rel(1, 0)
        screen.stroke()
        -- note indicator
        screen.level(15)
        screen.move(i * 46 - 46 + pattern.notes[i][j] + 8, j * 8 - 8 + 16)
        screen.line_rel(1, 0)
        screen.stroke()
        -- playheads
        screen.level(15)
        screen.move(i * 46 - 46 + 36, seq[i].pos * 8 - 8 + 16)
        screen.line_rel(4, 0)
        screen.stroke()
      end
    end
    -- draw octave seq
    for j = 1, 4 do
      -- note bars
      screen.line_width(6)
      screen.level((j == n_edit - 8) and 6 or 1)
      screen.move(100, j * 8 - 8 + 16)
      screen.line_rel(14, 0)
      screen.stroke()
      -- center indicator
      screen.level(0)
      screen.move(106, j * 8 - 8 + 16)
      screen.line_rel(2, 0)
      screen.stroke()
      -- note indicator
      screen.level(15)
      screen.move(106 + pattern.oct[j] * 2 , j * 8 - 8 + 16)
      screen.line_rel(2, 0)
      screen.stroke()
      -- playheads
      screen.level(15)
      screen.move(116, seq.oct_pos * 8 - 8 + 16)
      screen.line_rel(4, 0)
      screen.stroke()
    end
    -- draw destinations
    screen.line_width(1)
    for i = 1, 2 do
      -- destination fill
      screen.level(params:get("osc_assign"..i) == 1 and 0 or ((i * 3 - 3) + 1 == n_edit - 12 and 15 or 4)) -- osc
      screen.rect(i * 46 - 46 + 10, 47, 24, 6)
      screen.fill()
      screen.level(params:get("sub1_assign"..i) == 1 and 0 or ((i * 3 - 3) == n_edit - 14 and 15 or 4)) -- sub1
      screen.rect(i * 46 - 46 + 10, 56, 10, 6)
      screen.fill()
      screen.level(params:get("sub2_assign"..i) == 1 and 0 or ((i * 3 - 3) - 1 == n_edit - 16 and 15 or 4)) -- sub2
      screen.rect(i * 46 - 46 + 24, 56, 10, 6)
      screen.fill()
      screen.level(params:get("oct_assign"..i) == 1 and 0 or (i == n_edit - 18 and 15 or 4)) -- oct
      screen.rect(101, i * 8 - 8 + 47, 13, 6)
      screen.fill()
      -- destination boxes
      screen.level((i * 3 - 3) + 1 == n_edit - 12 and 15 or 4) -- osc
      screen.rect(i * 46 - 46 + 10, 47, 24, 6) -- osc
      screen.stroke()
      screen.level((i * 3 - 3) == n_edit - 14 and 15 or 4) -- sub1
      screen.rect(i * 46 - 46 + 10, 56, 10, 6)
      screen.stroke()
      screen.level((i * 3 - 3) - 1 == n_edit - 16 and 15 or 4) -- sub2
      screen.rect(i * 46 - 46 + 24, 56, 10, 6)
      screen.stroke()
      screen.level(i == n_edit - 18 and 15 or 4) -- oct
      screen.rect(101, i * 9 - 9 + 47, 13, 6)
      screen.stroke()
      -- destination glyphs
      screen.level(params:get("osc_assign"..1) == 2 and 0 or (n_edit == 13 and 15 or 4))
      screen.move(16, 50)
      screen.line_rel(11, 0)
      screen.stroke()
      screen.level(params:get("osc_assign"..2) == 2 and 0 or (n_edit == 16 and 15 or 4))
      screen.move(62, 49)
      screen.line_rel(11, 0)
      screen.move(62, 51)
      screen.line_rel(11, 0)
      screen.stroke()
      screen.level(params:get("oct_assign"..1) == 2 and 0 or (n_edit == 19 and 15 or 4))
      screen.move(104, 50)
      screen.line_rel(6, 0)
      screen.stroke()
      screen.level(params:get("oct_assign"..2) == 2 and 0 or (n_edit == 20 and 15 or 4))
      screen.move(104, 58)
      screen.line_rel(6, 0)
      screen.move(104, 60)
      screen.line_rel(6, 0)
      screen.stroke()
      screen.level(params:get("sub1_assign"..i) == 2 and 0 or ((i * 3 - 3) == n_edit - 14 and 15 or 4))
      screen.rect((i * 46 - 46) + 13, 57, 3, 3) -- sub1
      screen.fill()
      screen.level(params:get("sub2_assign"..i)  == 2 and 0 or ((i * 3 - 3) - 1 == n_edit - 16 and 15 or 4))
      screen.rect((i * 46 - 46) + 25, 57, 3, 3) -- sub2
      screen.rect((i * 46 - 46) + 29, 57, 3, 3)
      screen.fill()
    end

  elseif pageNum == 2 then
    screen.line_width(1)
    -- draw rytms
    for i = 1, 4 do
      screen.level(rytm[i].step and 15 or 4)
      screen.rect(i * 30 - 30 + 10, 12, 20, 20)
      screen.stroke()
      screen.level(i == r_edit and 15 or 4)
      for j = 1, params:get("rytm_div"..i) do
        if j < 5 then
          screen.rect((i * 30 - 30) + (j * 4) + 8, (4 * 4) + 10, 3, 3)
          screen.fill()
        end
        if j > 4 and j < 9 then
          screen.rect((i * 30 - 30) + (j * 4) - 8, (3 * 4) + 10, 3, 3)
          screen.fill()
        end
        if j > 8 and j < 13 then
          screen.rect((i * 30 - 30) + (j * 4) - 24, (2 * 4) + 10, 3, 3)
          screen.fill()
        end
        if j > 12 then
          screen.rect((i * 30 - 30) + (j * 4) - 40, (1 * 4) + 10, 3, 3)
          screen.fill()
        end
      end
    end
    for i = 1, 4 do
      -- destination fill
      screen.level(params:get("rytm_to_seq1"..i) == 1 and 0 or (i == r_edit - 4 and 15 or 4))
      screen.rect(i * 30 - 30 + 10, 36, 20, 8)
      screen.fill()
      screen.level(params:get("rytm_to_seq2"..i) == 1 and 0 or (i == r_edit - 8 and 15 or 4))
      screen.rect(i * 30 - 30 + 10, 2 * 10 - 10 + 36, 20, 8)
      screen.fill()
      screen.level(params:get("rytm_to_oct"..i) == 1 and 0 or (i == r_edit - 12 and 15 or 4))
      screen.rect(i * 30 - 30 + 10, 3 * 10 - 10 + 36, 20, 8)
      screen.fill()
      -- destination glyphs
      screen.level(params:get("rytm_to_seq1"..i) == 2 and 0 or (i == r_edit - 4 and 15 or 4))
      screen.rect(i * 30 - 30 + 18, 38, 3, 3) -- one
      screen.fill()
      screen.level(params:get("rytm_to_seq2"..i) == 2 and 0 or (i == r_edit - 8 and 15 or 4))
      screen.rect(i * 30 - 30 + 15, 48, 3, 3) -- two
      screen.rect(i * 30 - 30 + 21, 48, 3, 3)
      screen.fill()
      screen.level(params:get("rytm_to_oct"..i) == 2 and 0 or (i == r_edit - 12 and 15 or 4))
      screen.rect(i * 30 - 30 + 19, 59, 2, 2) -- oct
      screen.stroke()
      -- destination rectangles
      screen.level(i == r_edit - 4 and 15 or 4)
      screen.rect(i * 30 - 30 + 10, 36, 20, 8)
      screen.stroke()
      screen.level(i == r_edit - 8 and 15 or 4)
      screen.rect(i * 30 - 30 + 10, 2 * 10 - 10 + 36, 20, 8)
      screen.stroke()
      screen.level(i == r_edit - 12 and 15 or 4)
      screen.rect(i * 30 - 30 + 10, 3 * 10 - 10 + 36, 20, 8)
      screen.stroke()
    end

  elseif pageNum == 3 then
    screen.line_width(1)
    for i = 1, 2 do
      screen.level((i * 3 - 3) + 1 == o_edit and 15 or 4)
      screen.rect(i * 60 - 60 + 10, 18, 50, 12) -- osc
      screen.stroke()
      screen.level((i * 3 - 3) + 0 == o_edit - 2 and 15 or 4)
      screen.rect(i * 60 - 60 + 10, 36, 20, 20) -- sub1
      screen.stroke()
      screen.level((i * 3 - 3) - 1 == o_edit - 4 and 15 or 4)
      screen.rect(i * 60 - 60 + 40, 36, 20, 20) -- sub2
      screen.stroke()
    end
    if not shift then
      -- draw pitch
      for i = 1, 2 do
        screen.level((i * 3 - 3) + 1 == o_edit and 15 or 4)
        screen.rect(i * 60 - 60 + 9, 17, 51, 13) -- osc
        screen.fill()
        screen.level((i * 3 - 3) + 0 == o_edit - 2 and 15 or 4)
        screen.rect(i * 60 - 60 + 9, 35, 21, 21) -- sub1
        screen.fill()
        screen.level((i * 3 - 3) - 1 == o_edit - 4 and 15 or 4)
        screen.rect(i * 60 - 60 + 39, 35, 21, 21) -- sub2
        screen.fill()
        screen.level(0)
        screen.move(i * 60 - 60 + 35, 26)
        screen.text_center(params:string("freq_osc"..i))
      end
      -- draw sub1
      for i = 1, 2 do
        screen.level(0) -- (i * 3 - 3) + 0 == o_edit - 2 and 15 or 6
        for j = 1, params:get("freq_sub1"..i) do
          if j < 5 then
            screen.rect((i * 60 - 60) + (j * 4) + 8, (4 * 4) + 34, 3, 3)
            screen.fill()
          end
          if j > 4 and j < 9 then
            screen.rect((i * 60 - 60) + (j * 4) - 8, (3 * 4) + 34, 3, 3)
            screen.fill()
          end
          if j > 8 and j < 13 then
            screen.rect((i * 60 - 60) + (j * 4) - 24, (2 * 4) + 34, 3, 3)
            screen.fill()
          end
          if j > 12 then
            screen.rect((i * 60 - 60) + (j * 4) - 40, (1 * 4) + 34, 3, 3)
            screen.fill()
          end
        end
      end
      -- draw sub2
      for i = 1, 2 do
        screen.level(0)
        for j = 1, params:get("freq_sub2"..i) do
          if j < 5 then
            screen.rect((i * 60 - 60 + 30) + (j * 4) + 8, (4 * 4) + 34, 3, 3)
            screen.fill()
          end
          if j > 4 and j < 9 then
            screen.rect((i * 60 - 60 + 30) + (j * 4) - 8, (3 * 4) + 34, 3, 3)
            screen.fill()
          end
          if j > 8 and j < 13 then
            screen.rect((i * 60 - 60 + 30) + (j * 4) - 24, (2 * 4) + 34, 3, 3)
            screen.fill()
          end
          if j > 12 then
            screen.rect((i * 60 - 60 + 30) + (j * 4) - 40, (1 * 4) + 34, 3, 3)
            screen.fill()
          end
        end
      end
    else
      -- draw levels
      for i = 1, 2 do
        screen.level((i * 3 - 3) + 1 == o_edit and 15 or 4)
        screen.rect(i * 60 - 60 + 10, 18, params:get("level_osc"..i) * 4.9, 11)
        screen.fill()
      end
      for i = 1, 2 do
        screen.level((i * 3 - 3) + 0 == o_edit - 2 and 15 or 4)
        screen.rect(i * 60 - 60 + 10, 36, params:get("level_sub1"..i) * 1.9, 19)
        screen.fill()
      end
      for i = 1, 2 do
        screen.level((i * 3 - 3) - 1 == o_edit - 4 and 15 or 4)
        screen.rect(i * 60 - 60 + 40, 36, params:get("level_sub2"..i) * 1.9, 19)
        screen.fill()
      end
    end
  end
  screen.update()
end

function sup(page)
  if pageNum == page then
    dirtyscreen = true
  end
end

function screen_update()
  while true do
    clock.sleep(1/15)
    if dirtyscreen == true then
      redraw()
      dirtyscreen = false
    end
  end
end

function cleanup()
  grid.add = function() end
  crow.ii.jf.mode(0)
end
