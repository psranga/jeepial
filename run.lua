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

function test_execute_line(g, linenum, dst_values)
  local me = 'test_execline'
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

-- returns current value. then overwrites g with new_value.
function save_and_set_global_g(new_value)
  local me = 'save_g'
  local tmp = gx
  assert(type(tmp) == 'nil' or type(tmp) == 'table')  -- by reference
  assert(type(new_value) == 'nil' or type(new_value) == 'table')  -- by reference
  gx = new_value
  return tmp
end

-- returns a list of (dst, value) pairs.
function execute_line(g, linenum, built_values)
  local me = 'execline'
  local line = g.lines[linenum]

  local luacode = 'return ' .. line.code
  dlog4(me, 'luacode=', luacode)
  local codefn = load(luacode)
  if (codefn == nil) then
    dlog4(me, 'Lua error in luacode=', luacode, ' at linenum=', linenum)
  end
  assert(codefn ~= nil)

  -- change the global 'g' while we eval user code (eval lol #yolo).
  -- the identifier 'g' inside luacode is the current dst values.
  -- do this in a separate function b/c 'g' is in local scope.
  -- even if not, this is better b/c future-proofing.
  local prev_g = save_and_set_global_g(built_values)
  local retvals = table.pack(codefn())
  local g_used_in_eval = save_and_set_global_g(prev_g)

  line.done = 1  -- renaming takes care of loops; lines exec'd at most once per epoch

  local results = {}
  for i = 1, retvals.n do
    table.insert(results, retvals[i])
  end
  dlog4(me, 'got results', ' #dsts=', #line.dsts, ' results=', results)

  assert((#line.dsts == 0) or (#line.dsts >= 1 and is_seq(results) and #results == #line.dsts))

  local new_values = nil
  if #line.dsts == 0 then
    new_values = nil
  elseif #line.dsts == 1 then
    new_values = {{line.dsts[1], results[1]}}
  else
    -- zip of dsts and results.
    new_values = {}
    for i = 1, #line.dsts do
      table.insert(new_values, {line.dsts[i], results[i]})
    end
  end

  return new_values
end

function parsed_line_to_source(p)
  return p.linenum .. ' ' .. p.operation .. ' ' .. join(p.dsts, ', ') .. ': ' .. p.code .. '  -- deps: ' .. join(p.deps, ', ')
end

function run_epoch(g, epoch_num, built_values)
  local me = 'run_epoch'

  local value_updates = {}
  local pass_num = 0
  while true do
    pass_num = pass_num + 1
    local pass_str = epoch_num .. '.' .. pass_num
    dlog_lines(me, pass_str .. ' Values available in this pass:', built_values)
    dlog1(me, pass_str, ' Checking for ready lines.')
    dlog_flush()
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
      dlog(me, pass_str, ' All ready lines are preconditions. Done with this epoch.')
      dlog(me, pass_str, ' Value updates for next epoch:\n  #n=', #value_updates, '\n', join(map(value_updates, function(x, i) return '  ' .. i .. ' ' .. dlog_snippet(x) end), '\n'))
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
    function is_any_multivalued(value_updates)
      return num_multivalued(value_updates) > 1
    end

    function multivalued_updates(value_updates)
      -- is any value_update a list of lists?
      local r = {}
      for value_index, value_update in ipairs(value_updates) do
        local dst = value_update[1]
        local new_value = value_update[2]
        -- dlog('num_multivalued', 'value_update=', value_update)
        if type(new_value) == 'table' then dlog('num_multivalued', '#=', #new_value, ' =', new_value) end
        if type(new_value) == 'table' and #new_value > 1 then -- list of ...
          -- dlog('num_multivalued', '  new_value=', new_value)
          local ok = true
          for i, v in ipairs(new_value) do
            ok = ok and (type(v) == 'table' and #v == 1)
          end
          if ok then table.insert(r, value_index) end
        else
          -- dlog('num_multivalued', '  not table=', new_value, ' type=', type(new_value))
        end
      end
      return r
    end

    -- create multiple copies here if repeated values.
    -- and start off a parallel thread of execution.
    -- lol coroutine or closure?
    dlog_lines(me, pass_str .. ' Updating values received from ready lines: ', value_updates)

    local multi_indexes = multivalued_updates(value_updates)
    dlog(me, pass_str, ' multi_indexes=', multi_indexes)

    for i, v in ipairs(multi_indexes) do
      local value_update = value_updates[v]
      local built_values_copy = table.pack(table.unpack(built_values))
    end

    for i, v in ipairs(value_updates) do
      built_values[v[1]] = v[2]
    end
    dlog(me, pass_str, ' Updated values. Will check for new ready lines.')
  end

  return pass_num
end

function run_program(g)
  local me = 'run_program'

  local debug_info = join(map(g.lines, function (x) return '  ' .. parsed_line_to_source(x) end), '\n')
  dlog(me, 'running program:\n', debug_info, '\n')

  local values_snapshots = {} -- epoch_num -> built_values
  local epoch_num = 0
  local built_values = {START={}}

  while true do
    epoch_num = epoch_num + 1
    local epoch_str = epoch_num
    dlog_lines(me, epoch_str .. ' Values available at epoch start:', built_values)

    local num_passes = run_epoch(g, epoch_num, built_values)
    dlog1(me, epoch_str, ' num_passes=', num_passes)

    dlog_lines(me, epoch_str .. ' Values at epoch end: ', built_values)
    values_snapshots[epoch_num] = obj_to_str(built_values)  -- lol deep copy!

    if num_passes >= 1  then
      dlog('run_program', pass_num, ' This epoch had no updates? All epochs done.')
      break
    end

  end
end
