dofile('stdlib.lua')
dofile('csvlib.lua')
local luadate = require('luadate/src/date')

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
  return a[2]
end

function by_date(header, a)
  local i = header['date']
  return a[i]
end

function by_weekchange(header, a, b)
  return a[2] == '0'
end

function by_mweek(header, a)
  local i = header['mweek']
  return a[i]
end

function win_gridize(header, rows, sidx, eidx, part_idx)
  local ycoor_idx = add_field(header, 'ycoor')
  local xcoor_idx = add_field(header, 'xcoor')
  local cellvalue_idx = add_field(header, 'coorvalue')
  for i = sidx, eidx do
    local row = rows[i]
    row[ycoor_idx] = row[header['mweek']] - 1
    row[xcoor_idx] = row[header['dow']]
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
