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
    local s = ''
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

-- uses lambda pkf to provide sort keys that will be used to partition csv 't'.
-- table is returned sorted by pkf.
-- partitions are sorted by skf
-- pkf = partition key function
-- skt = sort key function
-- winf = window function that is called on every sorted partition.
--        it returns new values for existing columns, or new columns and values.
function csv_partition(t, pkf, skf, winf)
  local r = {}
  table.move(t, 1, #t, 1, r)
  if #r < 2 then return r end

  local parts = {}
  local sidx = 2
  local ks = pkf(header, r[2])

  for i, row in ipairs(r) do
    if i > 1 then
      local b = r[i]
      local kb = pkf(header, b)
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
  if #r >= 2 then
    table.insert(parts, {sidx, #r})
  end

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
      winf(r[1], u, 1, #u)
      table.move(u, 1, #u, sidx, r)
    end
  end

  return r,parts
end

function csv_partition_unused(t, pkf, skf, winf)
  local r = {}
  for i, row in ipairs(t) do
    if i > 1 then
      table.insert(r, row)
    end
  end
  local header = t[1]
  table.sort(r, function (a, b) return pkf(header, a) < pkf(header, b) end)
  table.insert(r, 1, t[1])
  if #r < 2 then return r end

  local parts = {}
  local sidx = 2
  local ks = pkf(header, r[2])

  for i, row in ipairs(r) do
    if i > 1 then
      local b = r[i]
      local kb = pkf(header, b)
      local is_new_part = (not (ks == kb))
      if is_new_part then
        eidx = i-1
        table.insert(parts, {sidx, eidx})
        sidx = i
        ks = kb
      end
    end
  end
  if #r >= 2 then
    table.insert(parts, {sidx, #r})
  end

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
      winf(r[1], u, 1, #u)
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
  table.insert(r, 1, t[1])
  return r
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
