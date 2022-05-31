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
    code = '[[' .. arg .. ']]'
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

function parsed_line_to_code3(p)
  local funcname = p.operation
  if funcname == 'goto' then
    funcname = 'ggoto'
  end
  local code = 'l2rtl.' .. funcname .. '(g, {dsts = ' .. funcall_snippet(p.dsts) .. ', code=' .. funcall_snippet(p.code) .. ', deps=' .. funcall_snippet(p.deps) .. '})'
  return code
end

function parsed_line_for_runlua(p)
  local funcname = p.operation
  if funcname == 'goto' then
    funcname = 'ggoto'
  end
  local deps_without_linenums = {}
  local linenum
  for i, v in ipairs(p.deps) do
    table.insert(deps_without_linenums, v[1])
    linenum = v[2]
  end
  local code = '  {linenum=' .. linenum .. ', operation=\'' .. funcname .. '\',\n'
  code = code .. '  code=' .. funcall_snippet(p.code) .. ',\n'
  code = code .. '  dsts=' .. funcall_snippet(p.dsts) .. ', deps=' .. funcall_snippet(deps_without_linenums) .. '}'
  return code
end

function parsed_line_to_source(p)
  return p.operation .. ' ' .. join(p.dsts, ', ') .. ': ' .. p.code
end

function parsed_lines_to_str(ctx, parsed_line_to_code_fn)
  -- local r = 'local l2rtl = require(\'l2rtl\')\ng = l2rtl.new_program()\n'
  local r = ''
  r = r .. 'dofile(\'run.lua\')\ndofile(\'l2rtl.lua\')\ng = {lines={\n'
  local code = ctx.code
  local lines = map(ctx.parsed_lines, parsed_line_to_code_fn)
  for i, s in ipairs(lines) do
    if i < #lines then s = s .. ',' end
    r = r .. s;
    if i < #lines then r = r .. '\n\n' end
  end
  r = r .. '\n}}\nrun_program(g)\n'
  return r
end

function runnable_code(ctx)
  return parsed_lines_to_str(ctx, parsed_line_for_runlua)
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
        local edge_label = dep_linenum .. '/' .. ctx.parsed_lines[dep_linenum].cmd
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

function is_system_dst(ctx, dst)
  if dst == endkey then return true end
  return false
end

function is_operation_renaming_immune(parsed_line)
  if parsed_line.operation == 'precondition' then return true end
  return false
end

function maybe_line_needs_renaming(p)
  return not is_operation_renaming_immune(p)
end

function rename_dsts(ctx)
  local rename_infos = find_dsts_to_be_renamed(ctx) -- [(dst, newname, linenum)]
  assert(ctx and ctx.debug_info)
  ctx.debug_info.rename_infos = rename_infos
  for i, rename_info in ipairs(rename_infos) do
    local dst_to_be_renamed, new_name, linenum = table.unpack(rename_info)
    local p = ctx.parsed_lines[linenum]

    local renamed_dsts = {}
    for j, dst in ipairs(p.dsts) do
      if dst == dst_to_be_renamed then
        table.insert(renamed_dsts, new_name)
      else
        table.insert(renamed_dsts, dst)
      end
    end

    local orig = p.dsts
    p.dsts = renamed_dsts
    dlog('renamed_dsts', 'line ', linenum, ' new dsts: ', renamed_dsts, ' orig: ', orig)
  end
end

function find_dsts_to_be_renamed_simple(ctx)
  -- if a dst has more than more inedge, then rename the second and subsequent occurrences.
  local dst_to_first_linenum = {}
  local dst_to_num_writes = {}
  local rename_infos = {}

  for i, p in ipairs(ctx.parsed_lines) do
    for j, dst in ipairs(p.dsts) do
      if is_system_dst(ctx, dst) then
        dlog6('find_dsts_to_be_renamed', 'ignoring system dst: ', dst)
      elseif is_operation_renaming_immune(p) == true then
        dlog2('find_dsts_to_be_renamed', 'ignoring renaming dst: ', dst, ' for renaming-immune operation: ', parsed_line_to_source(p))
      else
        if not dst_to_first_linenum[dst] then
          dst_to_first_linenum[dst] = i
        end
        if not dst_to_num_writes[dst] then
          dst_to_num_writes[dst] = 1
        else
          dst_to_num_writes[dst] = dst_to_num_writes[dst] + 1
          local new_name = dst .. dst_to_num_writes[dst]
          dlog2('find_dsts_to_be_renamed', 'renaming line ', i, ' dsts. dst: ', dst, ' -> ', new_name, ' ', parsed_line_to_source(p))
          table.insert(rename_infos, {dst, new_name, i})
        end
      end
    end
  end
  dlog4('find_dsts_to_be_renamed', 'dst_to_first_linenum: ', dst_to_first_linenum)
  dlog4('find_dsts_to_be_renamed', 'dst w/ multiple writes: ', filter_table(dst_to_num_writes, function(x) return x > 1 end))
  dlog2('find_dsts_to_be_renamed', 'need renaming: ', rename_infos)
  return rename_infos
end

function find_dsts_to_be_renamed_topo(ctx)
  local unresolved_nodes, inedge_to_level, resolved_levels, node_levels =
    topo_sort_symbolic(ctx)

  local rename_infos = {} -- [(dst, newname, linenum, write_num)]

  function make_rename_infos()
    local me = 'has_loop'
    dlog(me, 'unresolved nodes\' levels by inedge:')
    local ok = true

    for i, dst in ipairs(unresolved_nodes) do
      local lines_written_from = {}
      dlog(me, '  ', '* ', dst, ' (unresolved node)')
      local srcs = find_all_deps_of(ctx, dst)
      local loop_nums = {}
      for j, src in ipairs(srcs) do
        dlog(me, '    ', j, '. ', inedge_to_level[dst][src], ' via ', src)
        local tsrc, offset = table.unpack(inedge_to_level[dst][src])
        local has_loop_via_src = (tsrc == dst)

        if has_loop_via_src then
          local edges = find_all_edges(ctx, src, dst)
          assert(#edges == 1)
          local linenum_at_which_dst_should_be_renamed = edges[1][4]  -- it's a tuple

          local k = tsrc .. '-linenum-' .. linenum_at_which_dst_should_be_renamed
          if not loop_nums[k] then loop_nums[k] = 0 end
          loop_nums[k] = loop_nums[k] + 1  -- uniquify w/ linenum

          local new_name = dst .. '_from_' .. src
          local rename_info = {dst, new_name, linenum_at_which_dst_should_be_renamed, loop_nums[src]}
          table.insert(rename_infos, rename_info)
        end
      end

      dlog(me, 'loop_nums=', loop_nums)
      local num_loops = list_uniq(keys(loop_nums))

      if #num_loops > 1 then
        dlog(me, '  ', '! ', dst, ' loop expected: not found. num_loops=', num_loops)
        ok = false
      end
    end
    return ok
  end

  local ok = make_rename_infos()
  dlog_lines('find_rename', 'rename_infos:', rename_infos)

  assert(ok == true)

  return rename_infos
end

function find_dsts_to_be_renamed(ctx)
  return find_dsts_to_be_renamed_topo(ctx)
end

-- All info needed by runnable_code is needed here. But not anything more.
function topo_sort_symbolic(ctx)
  local roots = find_roots(ctx)
  local inedge_to_level = {} -- dst,src -> (dep, offset)
  local resolved_levels = {} -- dst -> (dep, offset)
  local node_levels = {}  -- dst -> level
  local me = 'sym_topo'
  local exclude_preconditions_etc = maybe_line_needs_renaming

  dlog(me, 'roots=', roots)
  table.sort(roots)

  local queue = {}  -- values are (dst, src)

  assert(list_find(roots, startkey))
  -- add all successors of roots to queue.
  for i, dst in ipairs(roots) do
    node_levels[dst] = 1
    resolved_levels[dst] = {dst, 0}
    local succs = find_all_dsts_of(ctx, dst)
    dlog(me, 'Add root successors: ', succs)
    for j, succ in ipairs(succs) do
      table.insert(queue, {succ, dst})
    end
  end

  function find_furthest_straight_line_predecessor(ctx, dst)
    local me = 'find_furthest_pred'
    --local dlog = function(...) return end
    local mysrcs = find_all_deps_of(ctx, dst, exclude_preconditions_etc)
    --dlog(me, 'dst=', dst, ' mysrcs=', mysrcs)
    local r = nil

    if #mysrcs == 0 then
      -- i'm a root. by definition return myself.
      r = {dst, 0}
    elseif #mysrcs > 1 then
      -- no straight line to my sources.
      r = nil
    else
      assert(#mysrcs == 1)
      local src = mysrcs[1]
      local cand = find_furthest_straight_line_predecessor(ctx, src)
      r = {src, 1}  -- one step away from my src
      if cand ~= nil then
        -- but rewrite from my src's predecessor if we found one.
        r = {cand[1], 1 + cand[2]}
      end
    end

    --dlog(me, 'dst=', dst, ' ret=', r)
    return r
  end

  while #queue > 0 do
    local dst, src = table.unpack(table.remove(queue, 1))
    dlog2(me, 'doing "', dst, '" reached from "', src, '"')

    -- should not have already done this edge.
    assert(inedge_to_level[dst] == nil or inedge_to_level[dst][src] == nil)
    if inedge_to_level[dst] == nil then inedge_to_level[dst] = {} end

    local resolved_src_level = resolved_levels[src]
    local mylevel = {src, 1}
    local mysrcs = find_all_deps_of(ctx, dst, exclude_preconditions_etc)
    local furthest_pred_level = find_furthest_straight_line_predecessor(ctx, src)
    dlog4(me, 'src\'s furthest_pred_level=', furthest_pred_level)

    -- if src is resolved, rewrite my level in terms of src.
    if resolved_src_level then
      dlog4(me, 'src=', src, ' is resolved: ', resolved_src_level)
      local src_of_src, src_offset = table.unpack(resolved_src_level)
      mylevel = {src_of_src, src_offset + 1}
    elseif furthest_pred_level then
      assert(furthest_pred_level[2] == 1 or furthest_pred_level[1] ~= src)
      mylevel = {furthest_pred_level[1], 1 + furthest_pred_level[2]}
    end

    -- set my level for this in-edge.
    inedge_to_level[dst][src] = mylevel
    dlog4(me, 'edge_level[', dst, ', ', src, '] = ', mylevel)

    -- if all inedges are resolved, resolve my *node* level.
    local done_mysrcs = keys(inedge_to_level[dst])
    if #done_mysrcs == #mysrcs then
      local mylevels = values(inedge_to_level[dst])
      local uniq_tsrcs = list_uniq(map(mylevels, function (x) return x[1] end))
      -- all inedges have the same transitive src?
      dlog4(me, '#uniq_tsrcs=', #uniq_tsrcs, ' uniq_tsrcs=', uniq_tsrcs, ' #mysrcs=', #mysrcs, ' #done_mysrcs=', #done_mysrcs)
      if #uniq_tsrcs == 1 then
        local resolved_tsrc = uniq_tsrcs[1]
        local resolved_offset = list_max(map(mylevels, function (x) return x[2] end))
        local resolved_level = {resolved_tsrc, resolved_offset}
        dlog4(me, '* level[', dst, '] = ', resolved_level)
        resolved_levels[dst] = resolved_level
      end
    end

    --[[
    if #mysrcs == 1 then -- and resolved_src_level then
      dlog4(me, '* level[', dst, '] = ', mylevel)
      resolved_levels[dst] = mylevel
    else
      local done_mysrcs = keys(inedge_to_level[dst])
      if #done_mysrcs == #mysrcs then
        local mylevels = values(inedge_to_level[dst])
        local uniq_tsrcs = list_uniq(map(mylevels, function (x) return x[1] end))
        -- all inedges have the same transitive src?
        dlog4(me, '#uniq_tsrcs=', #uniq_tsrcs, ' uniq_tsrcs=', uniq_tsrcs, ' #mysrcs=', #mysrcs, ' #done_mysrcs=', #done_mysrcs)
        if #uniq_tsrcs == 1 then
          local resolved_tsrc = uniq_tsrcs[1]
          local resolved_offset = list_max(map(mylevels, function (x) return x[2] end))
          local resolved_level = {resolved_tsrc, resolved_offset}
          dlog4(me, '* level[', dst, '] = ', resolved_level)
          resolved_levels[dst] = resolved_level
        end
      end
    end
    --]]

    local succs = find_all_dsts_of(ctx, dst, exclude_preconditions_etc)
    dlog4(me, 'Adding successors: ', succs)
    for j, succ in ipairs(succs) do
      if inedge_to_level[succ] == nil or inedge_to_level[succ][dst] == nil then
        local item = {succ, dst}
        dlog6(me, 'Adding item: ', item)
        table.insert(queue, item)
      end
    end
  end

  local resolved_nodes = keys(resolved_levels)
  local unresolved_nodes = list_difference(find_all_nodes(ctx), resolved_nodes)
  dlog_lines(me, 'resolved_nodes: ', resolved_nodes)
  dlog_lines(me, 'unresolved_nodes: ', unresolved_nodes)
  dlog_lines(me, 'resolved_levels:', resolved_levels)
  
  local roots_for_sym_levels = {}
  for dst, v in pairs(inedge_to_level) do
    for src, symlevel in pairs(v) do
      roots_for_sym_levels[symlevel[1]] = 1
    end
  end
  dlog(me, 'roots_for_sym_levels: ', keys(roots_for_sym_levels))

  return unresolved_nodes, inedge_to_level, resolved_levels, node_levels
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
            table.insert(edges, {dep, dst, p, linenum})
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
  local src, dst, parsed_line, linenum = table.unpack(edges[1])
  return parsed_line
end

function find_code_for_any_edge(ctx, needle_src, needle_dst)
  local edges = find_all_edges(ctx, needle_src, needle_dst)
  if #edges < 1 then return nil end
  local src, dst, parsed_line, linenum = table.unpack(edges[1])
  return parsed_line.code
end

function find_local_deps_for_any_edge(ctx, needle_src, needle_dst)
  local edges = find_all_edges(ctx, needle_src, needle_dst)
  if #edges < 1 then return nil end
  local src, dst, parsed_line, linenum = table.unpack(edges[1])
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

function find_roots(ctx)
  local dsts = find_all_nodes(ctx)
  local roots = {}
  for i, dst in ipairs(dsts) do
    local all_deps = find_all_deps_of(ctx, dst)
    if #all_deps == 0 then
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

function find_all_deps_of(ctx, needle_dst, line_filter)
  local nodes = {}
  for i, p in ipairs(ctx.parsed_lines) do
    if (line_filter == nil) or (line_filter(p, i) == true) then
      for j, dst in ipairs(p.dsts) do
        if dst == needle_dst then
          for k, depinfo in ipairs(p.deps) do
            local dep, linenum = table.unpack(depinfo)
            nodes[dep] = 1
          end
        end
      end
    end
  end
  return keys(nodes)
end

function find_all_dsts_of(ctx, needle_dep, line_filter)
  local nodes = {}
  for i, p in ipairs(ctx.parsed_lines) do
    if (line_filter == nil) or (line_filter(p, i) == true) then
      for j, dst in ipairs(p.dsts) do
        for k, depinfo in ipairs(p.deps) do
          local dep, linenum = table.unpack(depinfo)
          if dep == needle_dep then
            nodes[dst] = 1
          end
        end
      end
    end
  end
  return keys(nodes)
end

function gen_nonce(ctx)
  if not ctx.nonce then
    ctx.nonce = 0
  end
  ctx.nonce = ctx.nonce + 1
  return ctx.nonce
end

--[==[
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
--]==]

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
  if startswith(line, 'precondition ') then return compile_step('precondition', ctx, line) end
  dlog('compile_line', 'Ignoring line: ', line)
end

function compile_l2(buf)
  local i, s
  local lines = split(buf, '\n')
  for i, s in ipairs(lines) do
    dlog('compile_l2', 'line: ', i, ' ', s)
  end
  local ctx = {symtab = {}, dsts = {}, code = {}, parsed_lines = {}, debug_info = {}}
  local code = ctx.code
  for i, s in ipairs(lines) do
    if (s == '') or (s[1] == '#') then
      dlog('compile_l2', 'Ignoring: ', s)
    else
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

function test2()
  local s = [[
  init: dofile 'stdlib.lua'
  init: dofile 'l2rtl.lua'
  init: dofile 'crawl_sitemaps.lua'
  init: set_argv 'roots.txt' 'pages.txt'

  input root_sitemapstxt: argv(1)
  output write_allpages: write_as_lines_to_file argv(2) allpages

  -- build queue: new list
  -- build allpages: new list

  build root_sitemaps: lines_in_file root_sitemapstxt

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
  s = join(map(split(s, '\n'), trim), '\n')
  print(s)

  --dlog_disable('update_deps', 'compile_l2', 'compile_step')

  --print('--[[')
  local ctx = compile_l2(s)
  update_deps(ctx)
  print('ok')
  --print(graph_to_str(g))
  --print('--]]')
  print(runnable_code(ctx))
  --run_program(ctx, make_test_executor(ctx))
  -- print(write_graph(ctx))
end

function compile_stdin()
  local buf = io.read('a')

  print('--[[')
  local ctx = compile_l2(buf)
  update_deps(ctx)
  local code = runnable_code(ctx)
  print('--]]')
  io.write(code)
end

function program_for_dlog(ctx)
  local debug_info = join(map(ctx.parsed_lines, function (x, i) return '-- ' .. i .. ' ' .. parsed_line_to_source(x) end), '\n')
  local rename_infos = '-- rename_infos: ' .. obj_to_str(ctx.debug_info)
  return debug_info .. '\n' .. rename_infos
end

function write_graph_to_file(fn, ctx)
  local fh = io.open(fn, 'w+')
  local debug_info = program_for_dlog(ctx) -- join(map(ctx.parsed_lines, function (x, i) return '-- ' .. i .. ' ' .. parsed_line_to_source(x) end), '\n')
  fh:write('/* ', debug_info, ' */\n')
  fh:write(write_graph(ctx))
  fh:close()
end

function compile_args()
  local me = 'compile_args'
  assert(arg[1] ~= nil)
  assert(arg[2] ~= nil)
  assert(arg[3] ~= nil)
  assert(arg[4] ~= nil)

  dlog_disable('*', 'update_deps', 'compile_l2', 'compile_step', 'find_dsts_to_be_renamed')
  dlog_enable(me)

  io.input(arg[1])
  local buf = io.read('a')

  dlog(me, 'Compiling buf read from ', arg[1], ' with ', #buf, ' chars.')
  local ctx = compile_l2(buf)
  update_deps(ctx)  -- just in case: so dsts is known-good.
  write_graph_to_file(arg[4], ctx) -- dump graph before renaming for debugging

  rename_dsts(ctx)
  update_deps(ctx)
  write_graph_to_file(arg[3], ctx)

  dlog2(me, 'checking renaming.')
  local rename_infos = find_dsts_to_be_renamed(ctx)  -- should not see any candidates
  dlog2(me, 'second pass rename_infos: ', rename_infos)
  assert(#rename_infos == 0)

  local fh = io.open(arg[2], 'w+')
  local code = runnable_code(ctx)
  fh:write(program_for_dlog(ctx), '\n')
  fh:write(code)
  dlog(me, 'Done. ir=', arg[2], ' graph=', arg[3], ' dgraph=', arg[4])
end

function test_topo()
  dlog_disable('update_deps', 'compile_l2', 'compile_step', 'find_dsts_to_be_renamed')
  dlog_disable('is_seq')

  io.input('pg2.txt')
  local buf = io.read('a')

  local ctx = compile_l2(buf)
  update_deps(ctx)  -- just in case: so dsts is known-good.
  rename_dsts(ctx)
end

-- main()
-- test_l2_compile()
--test2()
-- compile_stdin()
compile_args()
-- test_topo()
