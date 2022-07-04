dofile('stdlib.lua')
dofile('csvlib.lua')

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

function win_gridize(header, rows, sidx, eidx)
  local ycoor_idx = add_field(header, 'ycoor')
  local xcoor_idx = add_field(header, 'xcoor')
  for i = sidx, eidx do
    local row = rows[i]
    row[ycoor_idx] = row[header['mweek']] - 1
    row[xcoor_idx] = row[header['dow']]
  end
end

function win_add_mweek(header, rows, sidx, eidx)
  local mweek_idx = add_field(header, 'mweek')

  local offset = rows[sidx][header['dow']]
  for i = sidx, eidx do
    local row = rows[i]
    row[mweek_idx] = math.floor((row[header['dd']] - 1) / 7) -- i - sidx + 1
  end
end
