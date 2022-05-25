dofile('stdlib.lua')

--[[
# build root_sitemaps: python [line for line in root_sitemaps.txt]
# build allpages: list
# build queue: root_sitemaps
# exit: if queue.length > 0
# build url, level: queue.pop()
# goto url, level: if level > 3
# build xml: wget url
# build pages, indexes: extract_from xml
# update queue: append [(x, level+1) for x in indexes]
# update allpages: append pages

# build root_sitemaps: python [line for line in root_sitemaps.txt]
# build allpages: list
# build queue: root_sitemaps
# foreach item: queue
#   build url, level: item
#   break: if level > 3
#   build xml: wget url
#   build pages, indexes: extract_from xml
#   update queue: append indexes
#   update allpages: append pages
# endforeach
--]]

startdst = 'START'
startkey = startdst
START = startdst
endkey = 'END'
outputskey = 'OUTPUTS'

-- deps is a list
function build(g, dst, rule, deps)
  local newkey = 1+#g
  g[newkey] = {cmd = 'build', dst = dst, rule = rule, deps = deps}
  return newkey
end

-- documentation only: nop.
function input(g, dst)
  -- connecting to START for display purposes.
  g[1+#g] = {cmd = 'dot', dst = {'INPUTS'}, rule = '', deps = {startkey}}
  local i, v
  for i, v in ipairs(dst) do
    g[1+#g] = {cmd = 'input', dst = {v}, rule = '', deps = {'INPUTS'}}
  end
  return 1
end

-- documentation only: nop
function output(g, deps)
  -- Using a "supernode" for dot display purposes.
  g[1+#g] = {cmd = 'output', dst = {'OUTPUTS'}, rule = '', deps = deps}
  g[1+#g] = {cmd = 'dot', dst = {endkey}, rule = '', deps = {'OUTPUTS'}}
  --[[
  for i, dep in ipairs(deps) do
    g[1+#g] = {cmd = 'output', dst = {'OUTPUTS'}, rule = '', deps = {dep}}
  end
  --]]
  return 1
end

function start(g, deps)
  local linenum = 1+#g
  local i, dep
  for i, dep in ipairs(deps) do
    g[1+#g] = {cmd = 'start', dst = {dep}, rule = '', deps = {startkey}}
  end
  return 1
end

--[[
-- TODO?: special case of build: sink so no dst (sinks cannot be referred to)
-- TODO?: output(g, {'allpages'}, {'allpages'})
-- syntax sugar for documentation/readability.
function output(g, dst)
  if rule == nil then rule = '' end
  g[1+#g] = {cmd = 'output', dst = dst, rule = '', deps = {}}
  return 1
end
--]]

function update(g, dst, rule, deps)
  g[1+#g] = {cmd = 'update', dst = dst, rule = rule, deps = deps}
  return 1
end

-- end_if(g, 'queue.length > 0', {'queue'})
function end_if(g, condition, deps)
  local linenum = 1+#g
  g[1+#g] = {cmd = 'end_if', dst = {outputskey}, rule = condition, deps = deps}
  return 1
end

function break_if(g, condition, deps)
  local linenum = 1+#g
  g[1+#g] = {cmd = 'break_if', dst = {'break_' .. linenum}, rule = condition, deps = deps}
  return 1
end

function goto_if(g, dst, condition, deps)
  local linenum = 1+#g
  g[1+#g] = {cmd = 'goto_if', dst = dst, rule = condition, deps = deps}
  return 1
end

function foreach(g, dst, rule, deps)
  local linenum = 1+#g
  g[1+#g] = {cmd = 'foreach', dst = dst, rule = rule, deps = deps}
  return 1
end

--[[
function endforeach(g, dst)
  local linenum = 1+#g
  local i, dep
  local myname = 'endfor_' .. linenum
  for i, v in ipairs(dst) do
    g[1+#g] = {cmd = 'endforeach', dst = {v}, rule = 'endforeach', deps = {myname}}
  end
  return 1
end
--]]

--[[
function list_to_str(l)
  local s, i
  s = '{'
  for i = 1, #l do
    if i > 1 then
      s = s .. ', '
    end
    s = s .. l[i]
    -- print(k .. ': ->', v)
  end
  s = s .. '}'
  return s
end
--]]

function graph_to_str(g)
  local k, v, s
  local s = '{' .. '\n'
  for k, v in ipairs(g) do
    -- print(k)
    s = s .. '  {'
    s = s .. 'linenum = '
    s = s .. k
    s = s .. ', '
    s = s .. 'cmd = \'' .. v.cmd .. '\', '
    s = s .. 'dst = ' .. list_to_str(v.dst) .. ', '
    s = s .. 'rule = \'' .. v.rule .. '\', '
    s = s .. 'deps = ' .. list_to_str(v.deps)
    s = s .. '}' .. '\n'
    -- print(k .. ': ->', v.linenum, v.dst, '"' .. v.rule .. '"', 'deps: ', list_to_str(v.deps))
  end
  s = s .. '\n' .. '}'
  return s
end

function print_graph(g)
  local k, v
  for k, v in ipairs(g) do
    -- print(k .. ': ->', v.linenum, v.dst, '"' .. v.rule .. '"', 'deps: ', list_to_str(v.deps))
    -- print(k .. ': ->', v)
  end
end

--[[
/*
The command line is

  dot -Tps -Grankdir=LR states.gv > states.ps

and the file is:
*/
digraph states {
    size="3,2";
	rankdir=LR;
    node [shape=ellipse];
    empty [label = "Empty"];
    stolen [label = "Stolen"];
    waiting [label = "Waiting"];
    full [label = "Full"];
    empty -> full [label = "return"]
    empty -> stolen [label = "dispatch", wt=28]
    stolen -> full [label = "return"];
    stolen -> waiting [label = "touch"];
    waiting -> full [label = "return"];
  }
]]--

function graph_to_dot(g)
  local s = [[digraph states {
	  size="3,2";
	  rankdir=TB;

  ]]
  -- write out the nodes.
  local k, v
  local nodes = {}
  for k, v in ipairs(g) do
    for i, dst in pairs(v.dst) do
      if not nodes[dst] then
        s = s .. dst .. ' [label = "' .. dst .. '"];\n'
        nodes[dst] = 1
      end
    end
  end

  -- write out the edges: edge from node to its deps.
  local i1, node, i2, dst, i3, dep
  for i1, node in ipairs(g) do
    for i2, dst in ipairs(node.dst) do
      for i3, dep in ipairs(node.deps) do
        local edge_label = i1
        s = s .. dep .. ' -> ' .. dst .. ' [label = "line-' .. edge_label .. '"] ;\n'
        -- s = s .. dst .. ' -> ' .. dep .. ' [label = "line-' .. edge_label .. '"] ;\n'
      end
    end
  end

  s = s .. '}\n'
  return s
end

-- also adds nodes for "code" lines (to merge multiple arcs with the same
-- annotation)
function graph_to_dot_detailed(g, detailed)
  local s = [[digraph states {
	  size="3,2";
	  rankdir=TB;

  ]]
  -- write out the nodes.
  local k, v
  local nodes = {}

  --[[
  for k, v in ipairs(g) do
    for i, dst in pairs(v.dst) do
      -- use shape=diamond for input.
      local shape
      if v.cmd == 'input' then
        shape = 'ellipse'  -- TODO
      else
        shape = 'ellipse'
      end
      if not nodes[dst] then
        s = s .. dst .. ' [label = "' .. dst .. '", shape=' .. shape .. '];\n'
        nodes[dst] = 1
      end
    end
  end

  -- use shape=diamond for output. TODO this is a NOP
  for k, v in ipairs(g) do
    if v.cmd == 'output' then
      for i, dep in pairs(v.deps) do
        local shape
        shape = 'circle'
        if not nodes[dep] then
          s = s .. dep .. ' [label = "' .. dep .. '", shape=' .. shape .. '];\n'
          nodes[dep] = 1
        end
      end
    end
  end
  --]]

  -- write out the edges: edge from node to its deps.
  nodes = {}
  local i1, node, i2, dst, i3, dep, doneedges, edge_label
  doneedges = {}
  for i1, node in ipairs(g) do
    for i2, dst in ipairs(node.dst) do
      for i3, dep in ipairs(node.deps) do
        if detailed then
          local code_node_name = 'line_' .. i1
          local code_node_label = node.cmd
          edge_label = code_node_name
          if not nodes[code_node_name] then
            s = s .. code_node_name .. ' [label = "' .. code_node_label .. '", shape=box];\n'
          end
          if not doneedges[dep .. code_node_name] then
            s = s .. dep .. ' -> ' .. code_node_name .. ' [label = "' .. edge_label .. '"] ;\n'
            doneedges[dep .. code_node_name] = 1
          end
          if not doneedges[code_node_name .. dst] then
            s = s .. code_node_name .. ' -> ' .. dst .. ' [label = "' .. edge_label .. '"] ;\n'
            doneedges[code_node_name .. dst] = 1
          end
        else
          local edge_label = 'line_' .. i1
          s = s .. dep .. ' -> ' .. dst .. ' [label = "' .. edge_label .. '"] ;\n'
        end
      end
    end
  end

  s = s .. '}\n'
  return s
end

function funcall_code_unused(ctx, funcname, ...)
  local code = funcname .. '('
  for i = 1, select('#', ...) do
    local arg = select(i, ...)
    if i > 1 then
      code = code .. ', '
    end
    local arg_code
    if type(arg) == 'number' then
      code = code .. arg
    elseif type(arg) == 'string' then
      code = code .. '[==[' .. arg .. ']==]'
    elseif type(arg) == 'table' then
      code = code .. '{' .. table.unpack(arg) .. '}'
    else dlog('fcc', 'bad arg of type ', type(arg), ' at ', i) end
  end
  code = code .. ')'
  dlog('fcc', 'output: ', code)
  return code
end

-- x formatted as lua source for a function call param.
function funcall_snippet(arg)
  local code = ''
  if type(arg) == 'number' then
    code = arg
  elseif type(arg) == 'string' then
    code = '\'' .. arg .. '\''
  elseif type(arg) == 'table' then
    local subargs = map(arg, funcall_snippet)
    code = '{' .. join(subargs, ', ') .. '}'
  elseif type(arg) == 'nil' then
    code = 'nil'
  else dlog('fcc', 'bad arg of type ', type(arg), ' at ', i) end
  return code
end

function parsed_line_to_code2(p)
  local funcname = p.operation
  local code = 'l2rtl.' .. funcname .. '(' .. funcall_snippet(p.dsts) .. ', ' .. funcall_snippet(p.code) .. ', ' .. funcall_snippet(p.deps) .. ')'
  return code
end

function parsed_line_to_code(p)
  local funcname = p.operation
  if funcname == 'goto' then
    funcname = 'ggoto'
  end
  local code = 'l2rtl.' .. funcname .. '(g, {dsts = ' .. funcall_snippet(p.dsts) .. ', code=' .. funcall_snippet(p.code) .. ', deps=' .. funcall_snippet(p.deps) .. '})'
  return code
end

function runnable_code(ctx)
  -- local r = 'local l2rtl = require(\'l2rtl\')\ng = l2rtl.new_program()\n'
  local r = 'dofile(\'l2rtl.lua\')\ng = l2rtl.new_program()\n'
  local code = ctx.code
  for i, s in ipairs(map(ctx.parsed_lines, parsed_line_to_code)) do
    r = r .. s .. '\n'
  end
  r = r .. 'l2rtl.run(g)\n'
  return r
end

-- <function> <arg> <arg> <arg>
function l2dsl_to_lua(s)
  local parts = split(s, '%s+') -- spaces within strings? YOLO.
  local funcname = parts[1]
  local r = funcname .. '(' .. join(parts, ', ', 2) .. ')'
  return r
end

function write_graph(ctx, detailed)
  local s = [[digraph states {
	  size="3,2";
	  rankdir=TB;

  ]]

  local k, v
  local nodes

  -- write out the edges: edge from node to its deps.
  nodes = {}
  local i1, p, i2, dst, i3, dep, doneedges, edge_label
  doneedges = {}
  for i1, p in ipairs(ctx.parsed_lines) do
    for i2, dst in ipairs(p.dsts) do
      for i3, dep_info in ipairs(p.deps) do
        local dep, dep_linenum = table.unpack(dep_info)
        local edge_label = ctx.parsed_lines[dep_linenum].cmd
        s = s .. dep .. ' -> ' .. dst .. ' [label = "' .. edge_label .. '"] ;\n'
        --[[if detailed then
          s = s .. dep .. ' -> ' .. dst .. ' [label = "' .. edge_label .. '"] ;\n'
        else
          s = s .. dep .. ' -> ' .. dst .. ';\n'
        end--]]
      end
    end
  end

  s = s .. '}\n'
  return s
end

-- split rule into words and for each word look in the symtab for whether it is a dep.
function update_deps(ctx)
  -- collect all dsts
  local all_dsts = {}
  for i, p in ipairs(ctx.parsed_lines) do
    for j, dst in ipairs(p.dsts) do
      all_dsts[dst] = 1
    end
  end
  ctx.symtab.dsts = keys(all_dsts)
  dlog('update_deps', 'all_dsts: ', ctx.symtab.dsts)

  -- loop and check if any dst appears in the code for a step.
  for linenum, p in ipairs(ctx.parsed_lines) do
    local code = string_copy_excluding_ranges(p.code, find_embedded_string_positions(p.code))
    dlog('update_deps', 'code=', code, ' p.code=', p.code, ' for dsts=', p.dsts)
    local patt = 's<.>/?;:\'"[{]}\\|=+-`~!@#$%^&*()]+,'
    local escaped_patt = ''
    for i = 1, #patt do
      escaped_patt = escaped_patt .. '%' .. string.sub(patt, i, i)
    end
    local words = split(code, '[' .. escaped_patt .. ']+')
    local deps = {}
    local num_deps = 0
    dlog('update_deps', 'words=', words)
    for j, w in ipairs(words) do
      dlog('update_deps', '  w=', w, ' all_dsts[w]=', all_dsts[w])
      if all_dsts[w] then
        -- there's a word 'w' that's a destination.
        -- ==> there's a dependency between w's destination ('p.dst') and 'w'.
        -- ==> Add w to 'p.deps'
        deps[w] = {w, linenum}
        num_deps = num_deps + 1
        dlog('update_deps', '    found dep: ', w)
      end
    end
    if num_deps == 0 then
      table.insert(deps, {START, linenum})
    end
    p.deps = values(deps)
    dlog('update_deps', '--> deps=', deps, " (code=", p.code, ')\n')
    -- dlog('update_deps', 'after: ', parsed_line_to_code(p))
  end

  local dst_to_deps = {}
  for i, dst in ipairs(ctx.symtab.dsts) do
    if not dst_to_deps[dst] then dst_to_deps[dst] = {} end

    for j, p in ipairs(ctx.parsed_lines) do
      if list_find(p.dsts, dst) then
        for k, dep_and_linenum in ipairs(p.deps) do
          local dep, linenum = table.unpack(dep_and_linenum)
          if not list_find(dst_to_deps[dst], dep) then
            table.insert(dst_to_deps[dst], dep)
            dlog('update_deps', 'adding dep', 'dst=', dst, ' dep=', dep)
          end
        end
      end
    end
  end
  ctx.symtab.dst_to_deps = dst_to_deps
  for dst, deps in pairs(dst_to_deps) do
    dlog('update_deps', 'dst_to_deps[', dst, '] = ', deps)
  end

  return ctx
end

-- returns the index of the parsed_line object from the table ctx.
-- or -1 if not found.
function find_any_index_of_dst(ctx, needle_dst)
  for i, p in ipairs(ctx.parsed_lines) do
    for j, dst in ipairs(p.dsts) do
      if needle_dst == dst then
        return i
      end
    end
  end
  return -1
end

function find_all_edges(ctx, needle_src, needle_dst)
  local edges = {}
  for i, p in ipairs(ctx.parsed_lines) do
    for j, dst in ipairs(p.dsts) do
      if dst == needle_dst then
        for k, depinfo in ipairs(p.deps) do
          local dep, linenum = table.unpack(depinfo)
          if dep == needle_src then
            table.insert(edges, {src, dst, p})
          end
        end
      end
    end
  end
  return edges
end

-- returns the parsed_line object, or nil if not found.
function find_any_edge(ctx, needle_src, needle_dst)
  local edges = find_all_edges(ctx, needle_src, needle_dst)
  if #edges < 1 then return nil end
  local src, dst, parsed_line = table.unpack(edges[1])
  return parsed_line
end

function find_code_for_any_edge(ctx, needle_src, needle_dst)
  local edges = find_all_edges(ctx, needle_src, needle_dst)
  if #edges < 1 then return nil end
  local src, dst, parsed_line = table.unpack(edges[1])
  return parsed_line.code
end

function find_local_deps_for_any_edge(ctx, needle_src, needle_dst)
  local edges = find_all_edges(ctx, needle_src, needle_dst)
  if #edges < 1 then return nil end
  local src, dst, parsed_line = table.unpack(edges[1])
  return parsed_line.deps
end

function find_all_nodes(ctx)
  local nodes = {}
  for i, p in ipairs(ctx.parsed_lines) do
    for j, dst in ipairs(p.dsts) do
      nodes[dst] = 1
      for k, depinfo in ipairs(p.deps) do
        local dep, linenum = table.unpack(depinfo)
        nodes[dep] = 1
      end
    end
  end
  return keys(nodes)
end

function find_all_deps_of(ctx, needle_dst)
  local nodes = {}
  for i, p in ipairs(ctx.parsed_lines) do
    for j, dst in ipairs(p.dsts) do
      if dst == needle_dst then
        for k, depinfo in ipairs(p.deps) do
          local dep, linenum = table.unpack(depinfo)
          nodes[dep] = 1
        end
      end
    end
  end
  return keys(nodes)
end

function find_all_dsts_of(ctx, needle_dep)
  dlog('find_all_dsts_of', needle_dep)
  local nodes = {}
  for i, p in ipairs(ctx.parsed_lines) do
    for j, dst in ipairs(p.dsts) do
      for k, depinfo in ipairs(p.deps) do
        local dep, linenum = table.unpack(depinfo)
        if dep == needle_dep then
          nodes[dst] = 1
        end
      end
    end
  end
  return keys(nodes)
end

function find_roots(ctx)
  local dsts = find_all_nodes(ctx)
  local roots = {}
  for i, dst in ipairs(dsts) do
    local all_deps = find_all_deps_of(ctx, dst)
    if (#all_deps == 0) or list_find(all_deps, startkey) then
      roots[1+#roots] = dst
    end
  end
  return roots
end

function find_sinks(ctx)
  local dsts = find_all_nodes(ctx)
  local sinks = {}
  for i, dst in ipairs(dsts) do
    local all_dsts = find_all_dsts_of(ctx, dst)
    if #all_dsts == 0 then
      sinks[1+#sinks] = dst
    end
  end
  return sinks
end

function gen_nonce(ctx)
  if not ctx.nonce then
    ctx.nonce = 0
  end
  ctx.nonce = ctx.nonce + 1
  return ctx.nonce
end

function run_program(ctx, executor)
  local roots = find_roots(ctx)
  local sinks = find_sinks(ctx)
  dlog('run_program', 'allnodes=', find_all_nodes(ctx))
  dlog('run_program', 'roots=', roots)
  dlog('run_program', 'sinks=', sinks)

  local ready_dsts = {}
  for i, dst in ipairs(roots) do
    table.insert(ready_dsts, {dst, startdst, 1}) -- no nonce. no unrolling happened.
  end

  dlog('run_program', '\n')
  local loopdet_dsts = {}
  local dst_values = {} -- map

  -- FIX THIS: use the linenum as the unit of execution.
  while #ready_dsts > 0 do
    dlog('run_program', 'ready_dsts=', ready_dsts)
    local rolled_dst, src, unroll_nonce = table.unpack(table.remove(ready_dsts, 1))
    local ready_dst = rolled_dst .. '-' .. unroll_nonce

    if loopdet_dsts[ready_dst] then
      dlog('run_program', 'ignoring for this epoch. ready_dst=', ready_dst, '. already done or in progress')
    else
      loopdet_dsts[ready_dst] = 1
      dlog('run_program', ready_dst, ' starting')

      local dst_value, unrolled_values = executor(rolled_dst, src, unroll_nonce, dst_values)

      dlog('run_program', ready_dst, ' value=', dst_value)
      dlog('run_program', ready_dst, ' unrolled_values=', unrolled_values)

      -- simple case: I wasn't unrolled. just schedule my successors.
      if not unrolled_values then
        local my_dsts = find_all_dsts_of(ctx, rolled_dst)
        dlog('run_program', ready_dst, ' my_dsts=', my_dsts)
        local ready_to_run = function(x)
        end
        for i, my_dst in ipairs(my_dsts) do
          if ready_to_run(my_dst) then
            dlog('run_program', ready_dst, ' scheduling dst=', my_dst)
            table.insert(ready_dsts, {my_dst, rolled_dst, 1})
          else
            dlog('run_program', ready_dst, ' not all deps ready for dst=', my_dst)
          end
        end
        dst_values[ready_dst] = dst_value
      end

      --[[if new_subroots then
        for i, subrootinfo in ipairs(new_subroots) do
          local new_dst, new_dst_value = table.unpack(subrootinfo)
          dlog('run_program', 'new_dst=', new_dst, ' index=', find_any_index_of_dst(ctx, new_dst))

          -- the proposed subtree's root can't already exist.
          assert(find_any_index_of_dst(ctx, new_dst) < 0)
          assert(dst_values[new_dst] == nil)

          -- the subtree root is already evaluated. Mark it ready so its
          -- successors can run.
          table.insert(ready_dsts, {new_dst, ready_dst})
          dst_values[new_dst] = new_dst_value
          loopdet_dsts[new_dst] = 1

          -- create unrolled parsed_line objects as if the user had unrolled.
          -- basically clone the current ready_dst with the nodename renamed.

          -- compute ready_dst's deps.
          -- TODO: consider multiple edges ending here from same src?
          local edges_ending_at_me = find_all_edges(ctx, src, ready_dst)
          assert(#edges_ending_at_me == 1)

          -- compute all forward arcs from here.
          local next_level_edges = find_next_edges(ctx, src, ready_dst)
          local mydsts = {}
          for i, v in ipairs(next_level_edges) do
            table.insert(mydsts, v[1]) -- it's a tuple of (src, dst, parsed_line)
          end

          -- my deps are the new node's deps are my deps.
          local new_deps = mydeps
          local new_linenum = save_parsed_line(ctx, 'unroll', {new_dst}, 'OPAQUE-UNROLL', new_deps)

          local my_parsed_line = edges[3] -- it's a (src, dst, parsed_line) tuple.

          -- add the subtree to the graph as if the input as unrolled ...
          local new_code = find_code_for_any_edge(ctx, src, new_dst) or ''
          local new_deps = find_local_deps_for_any_edge(ctx, src, new_dst) or {}
          dlog('run_program', 'new_subroot', ' dst=', new_dst, ' code=', new_code, ' deps=', new_deps)
          local new_linenum = save_parsed_line(ctx, 'unroll', {new_dst}, new_code, new_deps)

          -- ... then add me as the subtree's root as 
          table.insert(my_parsed_line.deps)

        end
      end--]]
      dlog('run_program', ready_dst, ' done\n')
    end
  end

  return ctx
end

function test_executor(dst, src, other_values, ctx)
  dlog('test_executor', 'dst=', dst, ' src=', src)
  if dst == "root_sitemapstxt" then
    return "root_sitemaps.txt", {}
  end
  if dst == "root_sitemaps" then
    return {'1.sitemap', '2.sitemap', '3.sitemap'}, {}
  end

  if dst == 'sitemap' then
    -- 'pbuild sitemap: unpack root_sitemaps'
    assert(src == 'root_sitemaps')

    local sitemaps = other_values[src] -- will be the list from the previous step.

    -- clone the 'sitemap' node once for each sitemap with a unique name.
    --[[
    local new_subroots = {}
    for i, v in ipairs(sitemaps) do
      local edges = find_all_edges(ctx, src, dst)
      assert(#edges == 1)

      local code = find_code_for_any_edge(ctx, src, dst) or ''
      local deps = find_local_deps_for_any_edge(ctx, src, dst) or {}
      dlog('test_executor', 'sitemap', ' code=', code, ' deps=', deps)

      local subroot = 'sitemap_' .. i;
      save_parsed_line(ctx, 'unroll', {subroot}, code, deps)
      table.insert(new_subroots, {subroot, v})
    end
    --]]
    local unrolled_values = {}
    for i, v in ipairs(sitemaps) do
      table.insert(unrolled_values, v)
    end

    return {}, unrolled_values
  end

  return nil
end

function make_test_executor(ctx)
  local executor = function(dst, src, other_values)
    return test_executor(dst, src, other_values, ctx)
  end

  return executor
end

-- All info needed by runnable_code is needed here. But not anything more.
function topo_sort_unused(ctx)

  function all_nodes(ctx)
    local nodes = {}
    for i, p in ipairs(ctx.parsed_lines) do
      for j, dst in ipairs(p.dsts) do
        nodes[dst] = 1
        for k, depinfo in ipairs(p.deps) do
          local dep, linenum = table.unpack(depinfo)
          nodes[dep] = 1
        end
      end
    end
    return keys(nodes)
  end

  function find_all_deps_of(ctx, needle_dst)
    local nodes = {}
    for i, p in ipairs(ctx.parsed_lines) do
      for j, dst in ipairs(p.dsts) do
        if dst == needle_dst then
          for k, depinfo in ipairs(p.deps) do
            local dep, linenum = table.unpack(depinfo)
            nodes[dep] = 1
          end
        end
      end
    end
    return keys(nodes)
  end

  function set_level(call_depth, dst, dst_to_level, path)
    if dst_to_level[dst] then return dst_to_level[level] end
    local prefix = rep('  ', call_depth+1);

    if path[dst] then  -- loop:
    end

    path[dst] = 1
    dlog('set_level', prefix, 'dst=', dst)

    local deps = find_all_deps_of(ctx, dst)
    dlog('set_level', prefix, '  deps=', deps)

    local max_level_of_deps = 0
    for i, dep in ipairs(deps) do
      if not dst_to_level[dep] then
        set_level(call_depth+1, dep, dst_to_level, path)
      end
      max_level_of_deps = max(max_level_of_deps, dst_to_level[dep])
    end
    dst_to_level[dst] = 1 + max_level_of_deps
    dlog('set_level', prefix, 'dst=', dst, ' gets level ', dst_to_level[dst])
    path[dst] = nil
    return dst_to_level[dst]
  end

  local nodes = all_nodes(ctx)
  local dst_to_level = {}
  local level_to_dsts = {}
  local done = {} -- presence/absence of key

  dlog('topo_sort', 'nodes=', nodes)

  for i, dst in ipairs(nodes) do
    dlog('topo_sort', '  doing: ', dst)
    if not done[dst] then
      local path = {}
      set_level(0, dst, dst_to_level, path)
      done[dst] = 1
    end
  end

  --[[
  for dst, level in pairs(dst_to_level) do
    if not level_to_dsts[level] then
      level_to_dsts[level] = {}
    end
    table.insert(level_to_dsts[level], dst)
  end

  ctx.dst_to_level = dst_to_level
  ctx.level_to_dsts = level_to_dsts
  dlog('topo_sort', 'dst_to_level=', dst_to_level)
  for i, dsts in ipairs(level_to_dsts) do
    dlog('topo_sort', 'level_to_dsts[', i, '] = ', level_to_dsts[i])
  end
  --]]
  return ctx
end

function save_parsed_line(ctx, operation, dsts, code, deps)
  local parsed_lines = ctx.parsed_lines
  local linenum = 1+#parsed_lines
  local t = {cmd = operation, operation = operation, dsts = dsts, code = code, deps = deps}
  parsed_lines[1+#parsed_lines] = t
  return #parsed_lines
end

-- input root_sitemapstxt: argv(1)
-- input <identifier>: code
--     l2rtl.input(identifier, code)
function compile_input(ctx, line)
  dlog('compile_step', line)
  local parts = split(line, '%s+')
  local dst = string.sub(parts[2], 1, -2) -- remove the trailing colon
  local code = parts[3]
  return save_parsed_line(ctx, 'input', {dst}, code)
end

-- output <identifier>: code
--     l2rtl.output(identifier, code)
function compile_output(ctx, line)
  dlog('compile_step', line)
  local parts = split(line, '%s+')
  local dst = string.sub(parts[2], 1, -2) -- remove the trailing colon
  local code = join(parts, ' ', 3, #parts)
  return save_parsed_line(ctx, 'output', {dst}, code)
end

-- <kw> <identifier>, <identifier>, ...: code
--     l2rtl.<kw>({identifier, ...}, code, {dep, dep, ...})
function compile_step(expected_kw, ctx, line)
  dlog('compile_step', 'expected_kw=', expected_kw, ' ', line)
  local kw_and_ids, rule = table.unpack(trim(split(line, ':')))
  local space_pos = string.find(kw_and_ids, ' ', 1, true)

  -- init can have no dsts.
  local kw = kw_and_ids
  local comma_sep_ids = ''
  if space_pos then
    kw = trim(string.sub(kw_and_ids, 1, space_pos-1))
    comma_sep_ids = trim(string.sub(kw_and_ids, space_pos+1))
  end
  assert(kw == expected_kw)

  local dsts = trim(split(comma_sep_ids, ','))
  return save_parsed_line(ctx, kw, dsts, rule)
end

-- build <identifier>, <identifier>, ...: code
--     l2rtl.build({identifier, ...}, code, {dep, dep, ...})
function compile_build(ctx, line)
  dlog('compile_build', line)
  return compile_rule('build', ctx, line)
end

function compile_line(ctx, line)
  if startswith(line, 'init:') then return compile_step('init', ctx, line) end
  if startswith(line, 'input ') then return compile_input(ctx, line) end
  if startswith(line, 'output ') then return compile_output(ctx, line) end
  if startswith(line, 'build ') then return compile_step('build', ctx, line) end
  if startswith(line, 'pbuild ') then return compile_step('pbuild', ctx, line) end
  if startswith(line, 'update ') then return compile_step('update', ctx, line) end
  if startswith(line, 'goto ') then return compile_step('goto', ctx, line) end
  dlog('compile_line', 'Ignoring line: ', line)
end

function compile_l2(buf)
  local i, s
  local lines = split(buf, '\n')
  for i, s in ipairs(lines) do
    dlog('compile_l2', 'line: ', i, ' ', s)
  end
  local ctx = {symtab = {}, dsts = {}, code = {}, parsed_lines = {}}
  local code = ctx.code
  for i, s in ipairs(lines) do
    if not (s == '') then
      code[1+#code] = compile_line(ctx, s)
    end
  end
  return ctx
end

function explicit_control_version(g)
  input(g, {'root_sitemapstxt'})  -- TODO: input/output processing. auto?
  output(g, {'allpages'})
  build(g, {'root_sitemaps'}, 'lua [line for line in root_sitemapstxt]', {'root_sitemapstxt'})
  build(g, {'allpages'}, 'new list', {})
  build(g, {'queue'}, 'copy root_sitemaps', {'root_sitemaps'})
  end_if(g, 'queue.length <= 0', {'queue'})
  build(g, {'item'}, 'queue.pop()', {'queue'})
  build(g, {'url', 'level'}, 'unpack item', {'item'})
  goto_if(g, {'anymore'}, 'level > 3', {'level'})
  build(g, {'anymore'}, 'queue.length > 0', {'queue'})
  goto_if(g, {'item'}, 'anymore != false', {'anymore'})
  build(g, {'xmlfile'}, 'wget url', {'url'})
  build(g, {'pages', 'indexes'}, 'extract_from xml', {'xmlfile'})
  update(g, {'queue'}, 'py append [(x, level+1) for x in indexes]', {'indexes', 'level'})
  update(g, {'allpages'}, 'append pages', {'pages'})
end

function foreach_version (g)
  --[[
  build root_sitemaps: python [line for line in root_sitemaps.txt]
  build allpages: list
  build queue: root_sitemaps
  foreach item: fifo queue
    build url, level: item
    break: if level > 3
    build xml: wget url
    build pages, indexes: extract_from xml
    update queue: append indexes
    update allpages: append pages
  endforeach
  --]]
  input(g, {'root_sitemapstxt'})  -- TODO: input/output processing. auto?
  output(g, {'allpages'})

  build(g, {'root_sitemaps'}, 'lua [line for line in root_sitemaps.txt]', {'root_sitemapstxt'})
  build(g, {'allpages'}, 'new list', {})
  build(g, {'queue'}, 'copy root_sitemaps', {'root_sitemaps'})
  foreach(g, {'item'}, 'fifo queue', {'queue'})
  build(g, {'url', 'level'}, 'unpack item', {'item'})
  break_if(g, 'level > 3', {'level'})
  build(g, {'xmlfile'}, 'wget url', {'url'})
  build(g, {'pages', 'indexes'}, 'extract_from xml', {'xmlfile'})
  update(g, {'queue'}, 'py append [(x, level+1) for x in indexes]', {'indexes', 'level'})
  update(g, {'allpages'}, 'append pages', {'pages'})
  -- endforeach(g, 'item')
  -- output(g, {'allpages'})
end

function main ()
  local g = {}

  -- TODO?: autoadd the dependencies to these.
  build(g, {'START'}, '', {})
  build(g, {'END'}, '', {})

  -- explicit_control_version(g)
  foreach_version(g)

  -- genius: *REBUILD*

  --[[
  build url, level: queue.pop()
  gate level <= 3
  build xml: wget url
  build pages, indexes: extract_from xml
  update queue: append indexes
  update allpages: append pages
  --]]

  -- print_graph(g)
  print('/*')
  print(graph_to_str(g))
  print('*/')
  print(graph_to_dot_detailed(g, true))
end

function test_l2_compile(buf)
  local g = {}
  io.input('l2rtl.lua')
  local rtl = io.read('a')

  local code = compile_l2(buf)

  io.output("test1.lua")
  io.write(rtl .. '\n' .. code)

  --local f = load(code)
  --if f then f() else print('error in eval.') end
end

local test1 = [[
input root_sitemapstxt: argv(1)
output allpages: write_as_lines_to_file argv(2) allpages

build root_sitemaps: lines_in_file root_sitemapstxt
build allpages: new list

build queue: new list
pbuild sitemap: unpack root_sitemaps
update queue: append (sitemap, 1)

goto END: if queue.length <= 0

build url, level: queue.pop()
goto url, level: if level > 3

build xml: wget url
build pages, indexes: process_one_sitemap xml

pbuild index: unpack indexes
update queue: append {index, level+1}

pbuild page: unpack pages
update allpages: append page

]]

-- main()
-- test_l2_compile()
local s = [[
init: dofile 'stdlib.lua'
init: dofile 'l2rtl.lua'
init: dofile 'crawl_sitemaps.lua'
init: set_argv 'roots.txt' 'pages.txt'

input root_sitemapstxt: argv(1)
output write_allpages: write_as_lines_to_file argv(2) allpages
build root_sitemaps: lines_in_file root_sitemapstxt
build allpages: new list

build queue: new list
pbuild sitemap: unpack root_sitemaps
update queue: append (sitemap, 1)

goto END: if queue.length <= 0
build url, level: queue.pop()
goto END: if level > 3

build xml: wget url
build pages, indexes: process_one_sitemap xml

pbuild index: unpack indexes
update queue: append {index, level+1}

pbuild page: unpack pages
update allpages: append page
]]

dlog_disable('update_deps', 'compile_l2', 'compile_step')

print('--[[')
local ctx = compile_l2(s)
-- split rule into words and for each word look in the symtab for whether it is a dep.
update_deps(ctx)
--print(graph_to_str(g))
print('--]]')
print(runnable_code(ctx))
run_program(ctx, make_test_executor(ctx))
-- print(write_graph(ctx))

--[[
local x = split('ab  cdxx ef', '%s+')
for i, s in ipairs(x) do
  print(s)
end
--]]
