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

function is_seq(t)
  local is_list = true
  local keys = {}
  local i = 0
  for k, v in pairs(t) do
    i = i + 1
    local is_num_key = (type(k) == 'number')
    if not is_num_key then return false end  -- all numeric keys
    if not (k ==  i) then return false end  -- no holes
  end
  return true
end

function is_list(t)
  return is_seq(t)
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
    local v_str
    if i > 1 then s = s .. ', ' end
    if type(v) == 'table' then
      if is_seq(v) then
        v_str = list_to_str(v)
      else
        v_str = map_to_str(v)
      end
    else
      v_str = v
    end
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
    if is_seq(v) then
      v_str = list_to_str(v)
    else
      v_str = v
    end
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

function dlog(loc, ...)
  if stdlib.disabled_dlog_sections[loc] then return end

  io.write('DLOG ', loc, ': ')
  for i = 1, select('#', ...) do
    -- if i > 1 then io.write(', ') end
    local arg = select(i, ...)
    io.write(dlog_snippet(arg))
  end
  io.write('\n')
end

function dlog_disable(section, ...)
  stdlib.disabled_dlog_sections[section] = 1
  for i = 1, select('#', ...) do
    local s = select(i, ...)
    stdlib.disabled_dlog_sections[s] = 1
  end
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

-- functions are applied from left to right with short-circuiting (f first).
function filter(l, f, ...)
  local o = {}
  for i, v in ipairs(l) do
    local ok = f(v)
    for i = 1, select('#', ...) do
      local g = select(i, ...)
      ok = ok and g(v) -- short-circuiting
    end
    if ok then
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
    for i = 1, select('#', ...) do
      local g = select(i, ...)
      ok = ok or g(v) -- short-circuiting
    end
    if ok then
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
    local t = f(v)
    for i = 1, select('#', ...) do
      local g = select(i, ...)
      t = g(t)
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

