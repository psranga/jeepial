dofile('stdlib.lua')

function write_as_lines_to_file(fn, l)
  local fh = io.open(fn, 'w+')
  for i, v in #ls do
    fh:write(v, '\n')
  end
  fh:close()
end

function lines_in_file(fn, l)
  local me = 'lines_in_file'
  local r = {}
  dlog(me, 'fn=', fn)
  dlog(me, ' within lines_in_file:', gx)
  local fh = io.open(fn)
  assert(fh ~= nil)
  while true do
    local s = fh:read()
    if not s then break end
    table.insert(r, s)
  end
  return r
end

function make_csv_header(csv)
  local header = {}
  for i, v in ipairs(csv[1]) do
    local k = string.lower(v)
    header[k] = i
    header[i] = v
  end
  return header
end

-- csv is assumed to have a header
function read_csv(fn)
  local lines = lines_in_file(fn)
  local r = {}
  for i, line in ipairs(lines) do
    table.insert(r, split(line, ','))
  end
  local header = make_csv_header(r)
  r[1] = header
  return r
end

function print_csv(t)
  for i, row in ipairs(t) do
    local s = '' .. pad_string('' .. i, 3) .. ': '
    for j, v in ipairs(row) do
      if j > 1 then s = s .. ',' end
      s = s .. v
    end
    print(s)
  end
end

-- uses lambda f to filter csv 't'.
function csv_filter(t, f)
  local r = {}
  for i, row in ipairs(t) do
    if f(i, row) ~= none then
      table.insert(r, row)
    end
  end
  return r
end

function call_wo_nil(f, ...)
  local args = {}
  for i = 1, select('#', ...) do
    local s = select(i, ...)
    if s == nil then
      -- nop
    else
      table.insert(args, s)
    end
  end
  return f(table.unpack(args))
end

-- groups 't' keys returned by 'gkf' returning the row-comparison key.
-- then sorts groups by keys returned by 'skf'.
-- then runs 'winf' within the groups.
-- groups are returned in arbitrary order
--   for now it is: sorted-by 'gkf' and 'skf' to break ties.
-- gkf = group key function
-- skt = within-group sort key function
-- winf = window function that is called on every sorted group.
--        it returns new values for existing columns, or new columns and values.
function csv_group(t, gkf, skf, winf)
  local r = {}
  table.move(t, 1, #t, 1, r)
  if #r < 2 then return r end

  local parts = {}
  local sidx = 2
  local ks = gkf(header, r[2])

  for i, row in ipairs(r) do
    if i > 1 then
      local b = r[i]
      local kb = gkf(header, b)
      local is_new_part = (not (ks == kb))
      print(i, is_new_part, ks, kb)
      if is_new_part then
        eidx = i-1
        table.insert(parts, {sidx, eidx})
        sidx = i
        ks = kb
      end
    end
  end
  assert(#r >= 2)
  table.insert(parts, {sidx, #r})

  if skf then
    for i, part in ipairs(parts) do
      local sidx, eidx = table.unpack(part)
      local u = {}
      table.move(r, sidx, eidx, 1, u)
      table.sort(u, function (a, b) return skf(header, a) < skf(header, b) end)
      table.move(u, 1, #u, sidx, r)
    end
  end

  if winf then
    for i, part in ipairs(parts) do
      local sidx, eidx = table.unpack(part)
      local u = {}
      table.move(r, sidx, eidx, 1, u)
      winf(r[1], u, 1, #u, i)
      table.move(u, 1, #u, sidx, r)
    end
  end

  return r,parts
end

-- TODO: generalize csv_partition and csv_group into one thing?
-- partitions 't' into non-decreasing partitions per breakpoint function 'bpf'.
-- "breakpoint function": returns a key that is used for comparisons.
--   the next partition starts from the breakpoint.
-- then optionally sorts partitions by keys returned by 'skf'.
-- then runs 'winf' within the partitions.
-- rows are permuted within partitions but relative order between partititions
--   does not change.
-- bpf = breakpoint function
-- skt = within-partition sort key function
-- winf = window function that is called on every sorted group.
--        it returns new values for existing columns, or new columns and values.
function csv_partition(t, bpf, skf, winf_or_list)
  assert(type(bpf) == 'function')
  assert(type(skf) == 'function')
  assert(type(winf_or_list) == 'function' or type(winf_or_list) == 'table')

  local compare_gt = function(a, b)
    if type(a) == 'boolean' then
      if a then a = 1 else a = 0 end
    end
    if type(b) == 'boolean' then
      if b then b = 1 else b = 0 end
    end
    return a > b
  end

  local r = t
  --table.move(t, 1, #t, 1, r)
  if #r < 3 then return r end

  local parts = {}
  local sidx = 2
  local eidx = sidx
  local header = r[1]

  for i, row in ipairs(r) do
    if i > 2 then
      local a = r[i-1]
      local b = r[i]
      local ka = bpf(header, a)
      local kb = bpf(header, b)
      local is_breakpoint = compare_gt(ka, kb)
      --print(i, is_breakpoint, ka, kb)
      if is_breakpoint then
        eidx = i-1
        table.insert(parts, {sidx, eidx})
        sidx = i
      end
    end
  end
  assert(#r >= 3)
  table.insert(parts, {sidx, #r})

  if skf then
    for i, part in ipairs(parts) do
      local sidx, eidx = table.unpack(part)
      local u = {}
      table.move(r, sidx, eidx, 1, u)
      table.sort(u, function (a, b) return skf(header, a) < skf(header, b) end)
      table.move(u, 1, #u, sidx, r)
    end
  end

  if winf_or_list then
    for i, part in ipairs(parts) do
      local sidx, eidx = table.unpack(part)
      local u = {}
      table.move(r, sidx, eidx, 1, u)
      if type(winf_or_list) ~= 'function' then
        for j, winf in ipairs(winf_or_list) do
          winf(r[1], u, 1, #u, i)
        end
      else
        local winf = winf_or_list
        winf(r[1], u, 1, #u, i)
      end
      table.move(u, 1, #u, sidx, r)
    end
  end

  return r,parts
end

function csv_sort(t, skf)
  local header = t[1]
  local r = {}
  table.move(t, 2, #t, 1, r)
  table.sort(r, function (a, b) return skf(header, a) < skf(header, b) end)
  table.move(r, 1, #r, 2, t)
  table.insert(r, 1, t[1])
  return t
end

function add_field(header, newfield)
  local newfield_idx
  if header[newfield] == nil then
    newfield_idx = #header + 1
    header[newfield_idx] = newfield
    header[newfield] = newfield_idx
  else
    newfield_idx = list_find(header, newfield)
  end
  return newfield_idx
end

function csv_unique_values(t, colidx)
  local lut = {}
  for i, row in ipairs(t) do
    if i > 1 then
      lut[row[colidx]] = 1
    end
  end

  local r = {}
  for k, v in pairs(lut) do
    table.insert(r, k)
  end

  return r
end

function csv_range(t, colidx, cmpfn)
  local unique_values = csv_unique_values(t, colidx)
  table.sort(unique_values, cmpfn)
  return unique_values[1], unique_values[#unique_values]
end

-- uses 'xcoor', 'ycoor', 'coorvalue'
-- returns a list of strings.
function csv_render_as_grid(t, rspec)
  local header = t[1]
  local xidx = header['xcoor']
  local yidx = header['ycoor']
  local valueidx = header['coorvalue']

  local first_x, last_x = csv_range(t, xidx)
  local first_y, last_y = csv_range(t, yidx)

  local header_rows = 0
  if rspec and rspec.thead then
    header_rows = 1
  end

  local datagrid = {}
  for i = first_y, last_y + header_rows do
    local row = {}
    for j = first_x, last_x do
      table.insert(row, '')
    end
    table.insert(datagrid, row)
  end

  local maxlen = 0

  for i, row in ipairs(t) do
    if i > 1 then
      local xcoor = row[xidx]
      local ycoor = row[yidx]
      local coorvalue = row[valueidx] .. ''
      maxlen = max(maxlen, #coorvalue)
      datagrid[ycoor-first_y+1+header_rows][xcoor-first_x+1] = coorvalue
    end
  end

  if header_rows > 0 then
    for i, v in ipairs(rspec.thead) do
      local coorvalue = v .. ''
      maxlen = max(maxlen, #coorvalue)
      datagrid[1][i] = coorvalue
    end
  end

  local lines = {}
  local maxlinelen = 0

  for i, row in ipairs(datagrid) do
    local s = ''
    for j, coorvalue in ipairs(row) do
      if j > 1 then s = s .. ' ' end
      s = s .. pad_string(coorvalue, maxlen)
      --if j < #row then s = s .. ' ' end
    end
    maxlinelen = max(maxlinelen, #s)
    table.insert(lines, s)
  end

  if rspec and rspec.title then
    table.insert(lines, 1, center_string(rspec.title, maxlinelen))
  end

  for i, line in ipairs(lines) do
    print(line)
  end

  -- character grid.
  -- num columns = maxlinelen
  -- num rows = #lines

  local r = {}

  local header = {}
  add_field(header, 'linenum')
  add_field(header, 'line')
  table.insert(r, 1, header)

  for i, line in ipairs(lines) do
    table.insert(r, {i, line})
  end

  return r
end

-- uses 'xcoor', 'ycoor', 'coorvalue'
-- returns a list of strings.
function csv_xx(t, rspec)
  local header = t[1]
  local xidx = header['xcoor']
  local yidx = header['ycoor']
  local valueidx = header['coorvalue']

  local first_x, last_x = csv_range(t, xidx)
  local first_y, last_y = csv_range(t, yidx)
  local datagrid = {}

  for i, row in ipairs(t) do
    if i > 1 then
      local xcoor = row[xidx]
      local ycoor = row[yidx]
      local coorvalue = row[valueidx]
      datagrid[ycoor][xcoor] = coorvalue
    end
  end
end
