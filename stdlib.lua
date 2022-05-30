function max(a, b, ...)
  if b == nil then return a end
  if a >= b then
    return max(a, ...)
  else
    return max(b, ...)
  end
end

function min(a, b, ...)
  if b == nil then return a end
  if a <= b then
    return min(a, ...)
  else
    return min(b, ...)
  end
end

-- puts the keys of t into an "array"
function keys(t)
  local r = {}
  for k, v in pairs(t) do
    r[1+#r] = k
  end
  table.sort(r)
  return r
end

-- values as an array
function values(t)
  local r = {}
  for k, v in pairs(t) do
    r[1+#r] = v
  end
  return r
end

function sorted(t, compfn)
  local r = {}
  for k, v in pairs(t) do
    r[k] = v
  end
  table.sort(r, compfn)
  return r
end

function startswith(s, pattern)
  local i, j
  i, j = string.find(s, pattern, 1)
  return i == 1
end

--[[
function is_seq(t)
  local keys = {}
  local i = 0
  for k, v in pairs(t) do
    i = i + 1
    local is_num_key = (type(k) == 'number')
    if not is_num_key then return nil end  -- all numeric keys
    if not (k == i) then return nil end  -- no holes
  end
  return 1
end
--]]
function is_seq(t)
  local n = 0
  for k, v in pairs(t) do
    n = n + 1
  end
  return #t == n  -- no other keys except those in table's "array view".
end

function is_list(t)
  return is_seq(t)
end

function obj_to_str(v)
  local v_str = v
  if type(v) == 'table' then
    if is_seq(v) then
      v_str = list_to_str(v)
    else
      v_str = map_to_str(v)
    end
  end
  if type(v) == 'function' then
    v_str = '<function>'
  end
  if type(v) == 'boolean' then
    if v == true then v_str = 'true' else v_str = 'false' end
  end
  return v_str
end

function list_to_str(x)
  if #x == 0 then return '[]' end
  local s = ''
  if #x > 1 and #x <= 4 then
    s = s .. '('
  else
    s = s .. '['
  end

  for i, v in ipairs(x) do
    if i > 1 then s = s .. ', ' end
    local v_str = obj_to_str(v)
    s = s .. v_str
  end

  if #x > 1 and #x <= 4 then
    s = s .. ')'
  else
    s = s .. ']'
  end
  return s
end

function map_to_str(x)
  local s = '{'
  local n = 1
  for k, v in pairs(x) do
    if n > 1 then s = s .. ', ' end
    local v_str = obj_to_str(v)
    s = s .. k .. '=' .. v_str
    n = n + 1
  end
  s = s .. '}'
  return s
end

function range(l, starti, endi)
  local t = {}
  if not starti then starti = 1 end
  if not endi then endi = #l end
  for i = starti, endi do
    t[1+#t] = l[i]
  end
  return t
end

function find_embedded_string_positions(instr, starti, endi)
  local t = {}
  if not starti then starti = 1 end
  if not endi then endi = string.len(instr) end
  local s = instr;

  -- dlog('find_embedded_string_positions', 's=', string.sub(s, starti, endi))
  local offset = 0

  while starti < endi do
    local sbegin, send;

    assert(starti < endi)
    sbegin = string.find(s, '%f[\'"]', starti)
    -- dlog('find_embedded_string_positions', 'sbegin=', sbegin)
    if not sbegin then break end
    if sbegin >= (endi-1) then break end

    assert(sbegin < endi)
    send = string.find(s, '%f[\'"]', sbegin+1)
    if not send then break end

    t[1+#t] = {offset+sbegin, offset+send}
    --dlog('find_embedded_string_positions', 'found string in range:', t[#t], ' = ', string.sub(instr, table.unpack(t[#t])))

    --dlog('find_embedded_string_positions', 'sbegin=', sbegin, ' send=', send, ' sub=', string.sub(s, sbegin, send))

    starti = send + 1
    if starti > endi then break end

    s = string.sub(s, starti)
    offset = offset + starti - 1
    starti = 1
    endi = string.len(s)

    -- dlog('find_embedded_string_positions', 's=', s)
  end
  return t
end

-- ranges is a list of 2-element lists (e.g., as returned by func above)
-- ranges have to be sorted by beginning subrange.
-- ranges cannot overlap.
function string_copy_excluding_ranges(s, ranges)
  local r = ''
  if #ranges == 0 then
    r = s
    return r
  end

  -- at least one range.
  local i = 1
  local prev_end = 0

  for i = 1, #ranges do
    local curr_begin, curr_end = table.unpack(ranges[i])
    --dlog('scer', 'i=', i, 'curr_begin=', curr_begin, ' curr_end=', curr_end)
    local left_of_range = string.sub(s, prev_end+1, curr_begin-1)
    --dlog('scer', 'left_of_range=', left_of_range)

    r = r .. left_of_range

    prev_end = curr_end
  end

  --dlog('scer', 'prev_end=', prev_end)
  local right_of_range = string.sub(s, prev_end+1)
  --dlog('scer', 'right_of_range=', right_of_range)
  r = r .. right_of_range

  return r
end

stdlib = {
  scer = string_copy_excluding_ranges,
  fesp = find_embedded_string_positions,
  disabled_dlog_sections = {} -- string keys
}

-- a,b,c -> [a, b, c]
-- a,b,c, -> [a, b, c, <empty value>]
-- ,a,b,c -> [<empty>, a, b, c]
-- TODO: return the separators also in parts?
function split(s, pattern)
  local i, j, j0
  local parts = {}
  if #s == 0 then return parts end
  i = nil
  j = nil
  j0 = 0
  i, j = string.find(s, pattern, j0+1)
  while i do
    parts[1+#parts] = string.sub(s, j0+1, i-1)
    j0 = j
    i, j = string.find(s, pattern, j0+1)
  end
  parts[1+#parts] = string.sub(s, j0+1)
  return parts
end

function splitfn(pattern)
  local f = function(s) return split(s, pattern) end
  return f
end

-- bind_back(f, a, b, c)(e, f, g) = f(e, f, g, a, b, c)
function bind_back(f, ...)
  local args = table.pack(...)
  local r = function(...) return f(..., table.unpack(args)) end
  return r
end

-- bind_front(f, a, b, c)(e, f, g) = f(a, b, c, e, f, g)
function bind_front(f, ...)
  local args = table.pack(...)
  local r = function(...) return f(table.unpack(args), ...) end
  return r
end

--[[
-- bindafter(f, a, b, c)(e, f, g) = f(e, f, g, a, b, c)
function bindafter(f, ...)
  local args = table.pack(...)
  local r = function(...) return f(..., table.unpack(args)) end
  return r
end

-- bindbefore(f, a, b, c)(e, f, g) = f(a, b, c, e, f, g)
function bindbefore(f, ...)
  local args = table.pack(...)
  local r = function(...) return f(table.unpack(args), ...) end
  return r
end
--]]

function join(l, sep, starti, endi)
  local s = ''
  if not starti then starti = 1 end
  if not endi then endi = #l end
  for i = starti, endi do
    if i > starti then s = s .. sep end
    s = s .. l[i]
  end
  return s
end

function dlog_snippet(x)
  if x == nil then
    return 'nil'
  end

  if type(x) == 'table' then
    if is_seq(x) then
      return list_to_str(x)
    else
      return map_to_str(x)
    end
  end

  return x
end

-- do something if s is shorter/longer than n.
function pad_or_shorten_loc_str(s, n)
  local padding = n - #s
  local r
  if padding == 0 then
    r = s
  elseif padding > 0 then -- s is shorter than n chars
    -- pad on the left
    r = rep(' ', padding) .. s
  else
    -- truncate from the right; delta is negative we need a positive offset
    -- fancy lol: use fewer chars for trunc marker if s is just a bit longer
    -- fancy2 lol: use the negative offsets of string.sub.
    local trunc_marker = string.sub('...', padding)
    local offset = (#s + #trunc_marker) - n
    r = string.sub(s, 1, -offset-1) .. trunc_marker
  end
  return r
end

function dlogue(loc, level, ...)
  if stdlib.disabled_dlog_sections[loc] == 1 then return end
  if stdlib.disabled_dlog_sections['*'] == 1 then return end

  local loc_str = loc
  if type(loc) == 'table' then
    loc_str = join(loc, '.')
  end

  loc_str = pad_or_shorten_loc_str(loc_str, 12)

  io.write('dlog', level, ' ', loc_str, ': ')
  for i = 1, select('#', ...) do
    -- if i > 1 then io.write(', ') end
    local arg = select(i, ...)
    io.write(dlog_snippet(arg))
  end
  io.write('\n')
end

function dlog(loc, ...)
  dlogue(loc, 1, ...)
end

function dlog1(...)
  return dlog(...)
end

function dlog8(loc, ...)
  dlogue(loc, 8, rep('  ', 4), ...)
end

function dlog6(loc, ...)
  dlogue(loc, 6, rep('  ', 3), ...)
end

function dlog4(loc, ...)
  dlogue(loc, 4, rep('  ', 2), ...)
end

function dlog2(loc, ...)
  dlogue(loc, 2, rep('  ', 1), ...)
end

function dlogue_lines(loc, level, title, lines)
  if stdlib.disabled_dlog_sections[loc] == 1 then return end
  if stdlib.disabled_dlog_sections['*'] == 1 then return end

  local loc_str = loc
  if type(loc) == 'table' then
    loc_str = join(loc, '.')
  end

  local s = 'llog' .. level .. ' ' .. loc .. ': '
  io.write(s, dlog_snippet(title), '\n')

  assert(type(lines) == 'table')

  if is_seq(lines) then
    for i = 1, #lines do
      io.write(rep(' ', #s), ' ', rep(' ', 1+math.floor(level/2)))
      io.write(i, '. ', dlog_snippet(lines[i]))
      io.write('\n')
    end
  else
    local i = 0
    for k, v in pairs(lines) do
      i = i + 1
      io.write(rep(' ', #s), ' ', rep(' ', 1+math.floor(level/2)))
      io.write('+ ', dlog_snippet(k), ' -> ', dlog_snippet(v))
      io.write('\n')
    end
  end
  -- io.write('\n')
end

--[[
function dlogue_lines(loc, level, title, ...)
  if stdlib.disabled_dlog_sections[loc] then return end

  local loc_str = loc
  if type(loc) == 'table' then
    loc_str = join(loc, '.')
  end

  local args = {}
  for i = 1, select('#', ...) do
    local arg = select(i, ...)
    table.insert(args, arg)
  end

  local s = 'llog' .. level .. ' ' .. loc .. ': '
  io.write(s, dlog_snippet(title), '\n')

  for i = 1, #args do
    io.write(rep(' ', #s), ' ', rep(' ', 1+math.floor(level/2)))
    io.write(i, '. ', dlog_snippet(args[i]))
    io.write('\n')
  end
  -- io.write('\n')
end
--]]

function dlog_lines(loc, ...)
  dlogue_lines(loc, 1, ...)
end

function map_to_kv_pairs(t)
  local r = {}
  for k, v in pairs(t) do
    table.insert(r, {k, v})
  end
  return r
end

-- r = m1 - m2
function set_difference(m1, m2)
  local r = {}
  for k, v in pairs(m1) do
    if not m2[k] then
      table.insert(r, k)
    end
  end
  return r
end

function list_difference(l1, l2)
  local m1 = {}
  local m2 = {}

  for i, v in ipairs(l1) do m1[v] = 1 end
  for i, v in ipairs(l2) do m2[v] = 1 end

  return set_difference(m1, m2)
end

function dlog_disable(section, ...)
  stdlib.disabled_dlog_sections[section] = 1
  for i = 1, select('#', ...) do
    local s = select(i, ...)
    stdlib.disabled_dlog_sections[s] = 1
  end
end

function dlog_enable(section, ...)
  stdlib.disabled_dlog_sections[section] = 0
  for i = 1, select('#', ...) do
    local s = select(i, ...)
    stdlib.disabled_dlog_sections[s] = 0
  end
end

function dlogger(me, debug_level, ...)
  local args = {}

  assert(me ~= nil)
  table.insert(args, me)

  if debug_level ~= nil then table.insert(args, debug_level) end

  for i = 1, select('#', ...) do
    local s = select(i, ...)
    table.insert(args, s)
  end

  return bind_front(dlog, table.unpack(args))
end

function rep(s, n)
  local r = ''
  for i = 1, n do
    r = r .. s
  end
  return r
end
-- remove leading and trailing space.
-- use gsub
function trim(s)
  if type(s) == 'table' then
    return map(s, trimleft, trimright)
  end
  return trimright(trimleft(s))
end

function trimleft(s)
  if type(s) == 'table' then
    return map(s, trimleft)
  end
  local t = string.gsub(s, '^%s+', '')
  return t
end

function trimright(s)
  if type(s) == 'table' then
    return map(s, trimleft)
  end
  local t = string.gsub(s, '%s+$', '')
  return t
end

--[[
function map(l, f)
  local o = {}
  for i, v in ipairs(l) do
    o[1+#o] = f(v)
  end
  return o
end
--]]

function list_sum(l)
  local r = 0
  for i, v in ipairs(l) do
    r = r + v
  end
  return r
end

function list_uniq(l)
  local r = {}
  for i, v in ipairs(l) do
    r[v] = 1
  end
  return keys(r)
end

-- functions are applied from left to right with short-circuiting (f first).
function map_table(l, f, ...)
  local o = {}
  for k, v in pairs(l) do
    local v2, k2 = f(v, k)
    for j = 1, select('#', ...) do
      local g = select(j, ...)
      v2, k2 = g(v2, k)
    end
    o[k] = v2
  end
  return o
end

-- functions are applied from left to right with short-circuiting (f first).
function filter_table(l, f, ...)
  local o = {}
  for k, v in pairs(l) do
    local ok = f(v, k)
    for j = 1, select('#', ...) do
      local g = select(j, ...)
      ok = (ok == true) and g(v, k) -- short-circuiting
    end
    if ok == true then
      o[k] = v
    end
  end
  return o
end

-- functions are applied from left to right with short-circuiting (f first).
function filter(l, f, ...)
  local o = {}
  for i, v in ipairs(l) do
    local ok = f(v, i)
    for j = 1, select('#', ...) do
      local g = select(j, ...)
      ok = (ok == true) and g(v, i) -- short-circuiting
    end
    if ok == true then
      o[1+#o] = v
    end
  end
  return o
end

-- functions are applied from left to right with short-circuiting (f first).
function filter_anytrue(l, f, ...)
  local o = {}
  for i, v in ipairs(l) do
    local ok = f(v)
    for j = 1, select('#', ...) do
      local g = select(j, ...)
      ok = ok or g(v, i) -- short-circuiting
    end
    if ok == true then
      o[1+#o] = v
    end
  end
  return o
end

-- returns [g(f(l[1])), g(f(l[2])), ...]
-- functions are applied from left to right.
function map(l, f, ...)
  local o = {}
  for i, v in ipairs(l) do
    local t = f(v, i)
    for j = 1, select('#', ...) do
      local g = select(j, ...)
      t = g(t, i)
    end
    o[1+#o] = t
  end
  return o
end

-- apply first function on x.
-- then apply the second function on the first result.
-- third on the second etc etc.
-- compose('a, b  , c,d', splitfn(','), trim)
--   returns ['a', 'b', 'c', 'd']
function compose(x, f, ...)
  local o = f(x)
  for i = 1, select('#', ...) do
    local g = select(i, ...)
    o = g(o)
  end
  return o
end

-- Same as the previous but the function object to be operated upon is
-- the *LAST* argument. The function declaration is written as below
-- for documentation purposes ('x' is by convention the name of the
-- object to be acted upon).
--
-- In the code itself, we rely on dynamic typing to finally use the
-- last argument as 'x'. But we need a minium of one function and one
-- object i.e., a minimum of two arguments.
function compose2(f, x, ...)
  assert(f ~= nil)
  assert(x ~= nil)

  if (f == nil) or (x == nil) then
    return nil
  end

  local args = {f, x}
  for i = 1, select('#', ...) do
    local g = select(i, ...)
    assert(g ~= nil)
    if g == nil then
      return nil
    end
    table.insert(args, g)
  end

  local obj = table.remove(args)
  return compose(obj, table.unpack(args))
end

function list_max(l)
  local o;
  for i, v in ipairs(l) do
    if i == 1 then
      o = v
    end
    if (not (v == nil)) and (not (o == nil)) then
      if v > o then
        o = v
      end
    end
  end
  return o
end

function list_min(l)
  local o;
  for i, v in ipairs(l) do
    if i == 1 then
      o = v
    end
    if (not (v == nil)) and (not (o == nil)) then
      if v < o then
        o = v
      end
    end
  end
  return o
end

-- returns the index, nil if not found.
function list_find(l, needle)
  for i, v in ipairs(l) do
    if v == needle then
      return i
    end
  end
  return nil
end

-- =============================

