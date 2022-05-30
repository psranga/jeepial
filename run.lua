dofile('stdlib.lua')

local startkey = 'START'
local endkey = 'END'

function find_ready_lines(g, built_values, excluded_operations)
  local me = 'f_ready_lines'

  local r = {}

  dlog2(me, 'find_ready_lines starting. #lines=', #g.lines)
  -- pass 1: roots
  for i, p in ipairs(g.lines) do
    local ok = true

    if list_find(excluded_operations, p.operation) then
      ok = false
    end

    if p.operation == 'output' then
      ok = false
    end

    if p.operation == 'build' and p.done == 1 then -- only 'new list'-like things
      ok = false
    end

    if p.operation == 'pbuild' and p.done == 1 then -- only for manual test for now.
      ok = false
    end

    if p.operation == 'update' and p.done == 1 then -- renaming
      ok = false
    end

    if p.operation == 'init' and p.done == 1 then
      ok = false
    end

    if p.operation == 'input' and p.done == 1 then
      ok = false
    end

    if #p.deps == 1 and p.deps[1] == startkey then
      ok = (ok == true) and true
    end

    if ok == true then
      for j, dep in ipairs(p.deps) do
        if not built_values[dep] then
          ok = false
          dlog6(me, ' linenum=', i, ' dep=', dep, ' is not ready. code=', p.code)
          break
        end
      end
      if ok == true then
        dlog6(me, ' linenum=', i, ' dsts=', p.dsts, ' all deps ready!')
      end
    end

    if ok == true then
      table.insert(r, i);
    end
  end

  table.sort(r)

  dlog2(me, 'find_ready_lines done. #ready=', #r)
  return r
end

function num_ready_lines_with_operation(ready_lines, g, operation)
  local n = 0
  for i = 1, #ready_lines do
    local linenum = ready_lines[i]
    local line = g.lines[linenum]
    if line.operation == operation then n = n + 1 end
  end
  dlog8('num_ready_lines_with_operation', ' n=', n, ' operation=', operation, ' #ready_lines=', #ready_lines)
  return n
end

function get_code(g, i)
  return g.lines[i].code
end

function test_execute_line(g, linenum, dst_values)
  local line = g.lines[linenum]
  if line.operation == 'init' then
    line.done = 1
    return {}
  end

  if line.operation == 'input' then
    line.done = 1
    return {{line.dsts[1], 'roots.txt'}}
  end

  --[[if linenum == 7 or linenum == 8 then -- 'new list'
    line.done = 1
    return {{line.dsts[1], {}}}
  end--]]

  if line.operation == 'build' then
    if line.dsts[1] == 'root_sitemaps' then
      line.done = 1
      return {{line.dsts[1], {'sitemap1.txt', 'sitemap2.txt', 'sitemap3.txt'}}}
    end
  end

  if line.operation == 'ggoto' then
    if string.find(line.code, 'queue') then
      local queue = dst_values.queue
      local r = (#queue <= 0)
      if r == true then
        return {{line.dsts[1], {src=linenum}}}
      end
    end
    if string.find(line.code, 'level') then
      local level = dst_values.level
      local r = level and (level > 3)
      if r == true then
        return {{line.dsts[1], {src=linenum}}}
      end
    end
  end

  if string.find(line.code, 'queue.pop()') then
    local queue = dst_values.queue
    local r = (#queue > 0)
    if r == true then
      return {{line.dsts[1], queue.remove()}}
    end
  end

  if string.find(line.code, 'unpack root_sitemaps') then
    line.done = 1
    local root_sitemaps = dst_values.root_sitemaps
    local r = {}
    for i, v in ipairs(root_sitemaps) do
      r[1+#r] = {line.dsts[1], v}
    end
    return r
  end

  dlog('execute_line', 'no match: ', linenum, ' ', line)
end

function execute_line(g, linenum, dst_values)
  local me = 'execute_line'
  local line = g.lines[linenum]
  v_level = 0  -- global on purpose

  function nopfn()
    return {}
  end

  local lut = {
    {op_patt='init', dsts_patt=nil, code_patt=nil, fn=nopfn},
    {op_patt='output', dsts_patt=nil, code_patt=nil, fn=nopfn},
    {op_patt='input', dsts_patt='root_sitemapstxt', code_patt=nil, fn=function() return 'roots.txt' end},
    {op_patt='build', dsts_patt='root_sitemaps', code_patt=nil, fn=function(l) return {'1.txt', '2.txt', '3.txt'} end},
    {op_patt='build', dsts_patt='^level$', code_patt='constant', fn=function() return 0 end},
    {op_patt='pbuild', dsts_patt='^url$', fn=function() return {'url1', 'url2', 'url3'} end},
    {op_patt='precondition', dsts_patt='xml', fn=function() return v_level <= 2 end},
    {op_patt='build', dsts_patt='xml', code_patt='wget', fn=function() return 'xmltext' end},
    {op_patt='update', dsts_patt='level.*', fn=function() return 1 end},
    {op_patt='build', code_patt='process_one_sitemap', fn=nopfn},
    {op_patt='pbuild', dsts_patt='url2', code_patt='unpack.*indexes', fn=function() return {'indexl1.1', 'index1.2', 'index1.3'} end},
    {op_patt='pbuild', dsts_patt='page', code_patt='unpack.*pages', fn=function() return {'page1.1', 'page1.2'} end},
    {op_patt='update', dsts_patt='allpages', code_patt='append', fn=nopfn},
  }

  for i, t in ipairs(lut) do
    dlog4(me, 'considering: ', t)
    local match = true

    if match and (line.operation ~= t.op_patt) then
      match = nil
    end

    if t.dsts_patt and (not string.find(join(line.dsts, ':'), t.dsts_patt)) then
      match = nil
    end

    if t.code_patt and (not string.find(line.code, t.code_patt)) then
      match = nil
    end

    if match then
      dlog4(me, 'executing lut entry: ', t)
      local r = t.fn(line)
      line.done = 1  -- renaming
      --[[if linenum==11 or linenum==7 or linenum==9 or string.find(line.code, 'constant') or string.find('init input', line.operation) then
        dlog('execute_line', '  marking done.')
        line.done = 1
      end--]]
      if #line.dsts > 0 then
        return {{line.dsts[1], r}}
      else
        return nil
      end
    end
  end

  dlog4(me, 'no match: ', linenum, ' ', line)
end

function parsed_line_to_source(p)
  return p.linenum .. ' ' .. p.operation .. ' ' .. join(p.dsts, ', ') .. ': ' .. p.code .. '  -- deps: ' .. join(p.deps, ', ')
end

function run_program(g)
  local me = 'run_program'
  built_values = {START={}}

  local debug_info = join(map(g.lines, function (x) return '  ' .. parsed_line_to_source(x) end), '\n')
  dlog('run_program', 'running program:\n', debug_info, '\n')

  local value_updates = {}
  local pass_num = 0
  while true do
    pass_num = pass_num + 1
    dlog1(me, pass_num, ' Checking for ready lines.')
    assert(pass_num < #g.lines)

    local ready_lines = find_ready_lines(g, built_values, {'output'})
    dlog1(me, 'ready_lines=', ready_lines)
    -- for-loop introduce a new indent level for logging.
    for i = 1, #ready_lines do
      dlog2(me, '  linenum=', ready_lines[i], ' ', g.lines[ready_lines[i]].code)
    end

    if #ready_lines == 0 then break end
    -- (within reason) 'if' condition doesn't introduce a new indent level for logging.
    if num_ready_lines_with_operation(ready_lines, g, 'precondition') == #ready_lines then
      dlog('run_program', pass_num, 'all ready lines are preconditions. Done with this epoch.')
      dlog('run_program', pass_num, 'value updates for next epoch:\n  #n=', #value_updates, '\n', join(map(value_updates, function(x, i) return '  ' .. i .. ' ' .. dlog_snippet(x) end), '\n'))
      break
    end

    local precondition_updates = {}

    while #ready_lines > 0 do
      local linenum = table.remove(ready_lines, 1)
      local line = g.lines[linenum]

      dlog2(me, 'executing line ', linenum, ' line=', parsed_line_to_source(line))
      local new_values = execute_line(g, linenum, built_values)

      -- here the 'if' should introduce a new level of logging.
      if new_values then
        dlog2(me, 'executed line ', linenum, ' new_values=', new_values)
        if line.operation == 'precondition' then
          for i, v in ipairs(new_values) do
            table.insert(precondition_updates, v)
          end
        else
          for i, v in ipairs(new_values) do
            table.insert(value_updates, v)
          end
        end
      else
        dlog2(me, 'executed line ', linenum, ': NO new values.')
      end
    end

    -- update values
    -- create multiple copies here if repeated values.
    -- and start off a parallel thread of execution.
    -- lol coroutine or closure?
    dlog(me, pass_num, ' Updating values received from ready lines: ', map(value_updates, function (u) return u[1] end))
    for i, v in ipairs(value_updates) do
      built_values[v[1]] = v[2]
    end
    dlog(me, pass_num, ' Updated values. Will check for new ready lines.')
  end
end

