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

startkey = 'START'
endkey = 'END'
outputskey = 'OUTPUTS'

-- deps is a list
function build(g, dst, rule, deps)
  local newkey = 1+#g
  g[newkey] = {cmd = 'build', dst = dst, rule = rule, deps = deps}
  return newkey
end

-- documentation only: nop.
function inputs(g, dst)
  -- connecting to START for display purposes.
  g[1+#g] = {cmd = 'dot', dst = {'INPUTS'}, rule = '', deps = {startkey}}
  local i, v
  for i, v in ipairs(dst) do
    g[1+#g] = {cmd = 'input', dst = {v}, rule = '', deps = {'INPUTS'}}
  end
  return 1
end

-- documentation only: nop
function outputs(g, deps)
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
      -- use shape=diamond for inputs.
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

  -- use shape=diamond for outputs. TODO this is a NOP
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

--[[
inputs(g, {'root_sitemapstxt'})
outputs(g, {'allpages'})
build(g, {'root_sitemapstxt'}, '', {})
build(g, {'root_sitemaps'}, 'lua [line for line in root_sitemaps.txt]', {'root_sitemapstxt'})
build(g, {'allpages'}, 'new list', {})
build(g, {'queue'}, 'copy root_sitemaps', {'root_sitemaps'})
end_if(g, 'queue.length <= 0', {'queue'})
build(g, {'item'}, 'queue.pop()', {'queue'})
build(g, {'url', 'level'}, 'unpack item', {'item'})
goto_if(g, 'item', 'level > 3', {'level'})
build(g, {'xmlfile'}, 'wget url', {'url'})
build(g, {'pages', 'indexes'}, 'extract_from xml', {'xmlfile'})
update(g, {'queue'}, 'py append [(x, level+1) for x in indexes]', {'indexes', 'level'})
update(g, {'allpages'}, 'append pages', {'pages'})
--]]
function explicit_control_version(g)
  inputs(g, {'root_sitemapstxt'})  -- TODO: input/output processing. auto?
  outputs(g, {'allpages'})
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
  inputs(g, {'root_sitemapstxt'})  -- TODO: input/output processing. auto?
  outputs(g, {'allpages'})

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
  print(graph_to_dot_detailed(g, false))
end

main()

