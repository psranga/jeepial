local luadate = require('luadate/src/date')
dofile('stdlib.lua')
dofile('csvlib.lua')

function gen_cal(y, m)
  local r = {}
  local header = {}
  add_field(header, 'date')
  add_field(header, 'dow')
  add_field(header, 'yy')
  add_field(header, 'mm')
  add_field(header, 'dd')
  table.insert(r, header)

  for d = 1,32 do
    local o = luadate(y, m, d)
    if o:getmonth() ~= m then break end

    local row = {o:fmt('%F'), o:getweekday(), o:fmt('%Y'), o:fmt('%m'), o:fmt('%d')}
    table.insert(r, row)
  end

  return r
end

function by_dow(header, a)
  return a[header['dow']]
end

function by_date(header, a)
  local i = header['date']
  return a[i]
end

function win_gridize_unused(header, rows, sidx, eidx, part_idx)
  local ycoor_idx = add_field(header, 'ycoor')
  local xcoor_idx = add_field(header, 'xcoor')
  local cellvalue_idx = add_field(header, 'coorvalue')
  for i = sidx, eidx do
    local row = rows[i]
    row[ycoor_idx] = row[header['mweek']] - 1
    row[xcoor_idx] = row[header['dow']] - 1
    row[cellvalue_idx] = math.floor(row[header['dd']] + 0)
  end
end

function win_add_mweek(header, rows, sidx, eidx, part_idx)
  local mweek_idx = add_field(header, 'mweek')
  for i = sidx, eidx do
    local row = rows[i]
    row[mweek_idx] = part_idx
  end
end

function win_gridize(header, rows, sidx, eidx, part_idx)
  local ycoor_idx = add_field(header, 'ycoor')
  local xcoor_idx = add_field(header, 'xcoor')
  local cellvalue_idx = add_field(header, 'coorvalue')
  for i = sidx, eidx do
    local row = rows[i]
    row[ycoor_idx] = part_idx
    row[xcoor_idx] = row[header['dow']] - 1
    row[cellvalue_idx] = math.floor(row[header['dd']] + 0)
  end
end

function doit()
  local y = arg[1]
  assert(y)

  for midx = 2, #arg do
    local m = math.floor(arg[midx] + 0)
    assert(m)
    local t = gen_cal(y, m)
    csv_sort(t, by_date)
    print('Timeline:')
    print_csv(t)

    local t, parts = csv_partition(t, by_dow, by_date, win_gridize)
    print('After partitioning by day-of-week, and setting xcoor=dow, ycoor=partition index')
    print_csv(t)
    print('Partitions (start index, end index) within table')
    print_csv(parts)

    print('Calendar view = auto render table as a grid (using xcoor, ycoor columns)')
    local lines = csv_render_as_grid(t, {title = y .. '/' .. m,
      thead = {'Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'}})
    print()

    print('The final result is also a table (character grid)')
    print_csv(lines)
  end
end

doit()
