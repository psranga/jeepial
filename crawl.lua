--[[
# build root_sitemaps: python [line for line in root_sitemaps.txt]
# build allpages: list
# build queue: root_sitemaps
# gate queue.length > 0
# build url, level: queue.pop()
# gate level <= 3
# build xml: wget url
# build pages, indexes: extract_from xml
# update queue: append indexes
# update allpages: append pages

# build root_sitemaps: python [line for line in root_sitemaps.txt]
# build allpages: list
# build queue: root_sitemaps
# foreach item: queue
#   build url, level: item
#   break_if level > 3
#   build xml: wget url
#   build pages, indexes: extract_from xml
#   update queue: append indexes
#   update allpages: append pages
# endforeach
--]]

startkey = 'START'
endkey = 'END'

-- deps is a list
function build(g, dst, rule, deps)
  g[1+#g] = {cmd = 'build', dst = dst, rule = rule, deps = deps}
  return 1
end

function update(g, dst, rule, deps)
  g[1+#g] = {cmd = 'update', dst = dst, rule = rule, deps = deps}
  return 1
end

-- end_if(g, 'queue.length > 0', {'queue'})
function end_if(g, condition, deps)
  local linenum = 1+#g
  g[1+#g] = {cmd = 'end_if', dst = {endkey}, rule = condition, deps = deps}
  return 1
end

function break_if(g, condition, deps)
  local linenum = 1+#g
  g[1+#g] = {cmd = 'break_if', dst = {'break_' .. linenum}, rule = condition, deps = deps}
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
  for i, v in pairs(dst) do
    g[1+#g] = {cmd = 'endforeach', dst = {v}, rule = 'endforeach', deps = {myname}}
  end
  return 1
end
--]]

function start(g, deps)
  local linenum = 1+#g
  local i, dep
  for i, dep in pairs(deps) do
    g[1+#g] = {cmd = 'start', dst = {dep}, rule = '', deps = {startkey}}
  end
  return 1
end

function output(g, deps)
  local linenum = 1+#g
  g[1+#g] = {cmd = 'output', dst = {endkey}, rule = '', deps = deps}
  return 1
end

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
  for k, v in pairs(g) do
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
  for k, v in pairs(g) do
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
  for k, v in pairs(g) do
    for i, dst in pairs(v.dst) do
      s = s .. dst .. ' [label = "' .. dst .. '"];\n'
    end
  end

  -- write out the edges: edge from node to its deps.
  local i1, node, i2, dst, i3, dep
  for i1, node in pairs(g) do
    for i2, dst in pairs(node.dst) do
      for i3, dep in pairs(node.deps) do
        local edge_label = i1
        s = s .. dep .. ' -> ' .. dst .. ' [label = "line-' .. edge_label .. '"] ;\n'
        -- s = s .. dst .. ' -> ' .. dep .. ' [label = "line-' .. edge_label .. '"] ;\n'
      end
    end
  end

  s = s .. '}\n'
  return s
end

function explicit_control_version(g)
  start(g, {'root_sitemapstxt'})
  build(g, {'root_sitemapstxt'}, '', {})
  build(g, {'root_sitemaps'}, 'lua [line for line in root_sitemaps.txt]', {'root_sitemapstxt'})
  build(g, {'allpages'}, 'new list', {})
  build(g, {'queue'}, 'copy root_sitemaps', {'root_sitemaps'})
  goto_if(g, {'END'}, 'queue.length <= 0', {'queue'})
  build(g, {'item'}, 'queue.pop()', {'queue'})
  build(g, {'url', 'level'}, 'unpack item', {'item'})
  goto_if(g, {'item'}, 'level > 3', {'level'})
  build(g, {'xmlfile'}, 'wget url', {'url'})
  build(g, {'pages', 'indexes'}, 'extract_from xml', {'xmlfile'})
  update(g, {'queue'}, 'append indexes', {'indexes'})
  update(g, {'allpages'}, 'append pages', {'pages'})
  -- output(g, {'allpages'})
end

function foreach_version (g)
  --[[
  build root_sitemaps: python [line for line in root_sitemaps.txt]
  build allpages: list
  build queue: root_sitemaps
  foreach item: fifo queue
    build url, level: item
    break_if level > 3
    build xml: wget url
    build pages, indexes: extract_from xml
    update queue: append indexes
    update allpages: append pages
  endforeach
  --]]
  build(g, {'root_sitemapstxt'}, '', {})
  build(g, {'root_sitemaps'}, 'lua [line for line in root_sitemaps.txt]', {'root_sitemapstxt'})
  build(g, {'allpages'}, 'new list', {})
  build(g, {'queue'}, 'copy root_sitemaps', {'root_sitemaps'})
  foreach(g, {'item'}, 'fifo queue', {'queue'})
  build(g, {'url', 'level'}, 'unpack item', {'item'})
  break_if(g, 'level > 3', {'level'})
  build(g, {'xmlfile'}, 'wget url', {'url'})
  build(g, {'pages', 'indexes'}, 'extract_from xml', {'xmlfile'})
  update(g, {'queue'}, 'append indexes', {'indexes'})
  update(g, {'allpages'}, 'append pages', {'pages'})
  -- endforeach(g, 'item')
  -- output(g, {'allpages'})
end

local g = {}

-- TODO?: autoadd the dependencies to these.
build(g, {'START'}, '', {})
build(g, {'END'}, '', {})

explicit_control_version(g)
-- foreach_version(g)

--[[
-- start(g, {'root_sitemapstxt'})
build(g, {'root_sitemapstxt'}, '', {})
build(g, {'root_sitemaps'}, 'lua [line for line in root_sitemaps.txt]', {'root_sitemapstxt'})
build(g, {'allpages'}, 'new list', {})
build(g, {'queue'}, 'copy root_sitemaps', {'root_sitemaps'})
end_if(g, 'queue.length <= 0', {'queue'})
build(g, {'item'}, 'queue.pop()', {'queue'})
build(g, {'url', 'level'}, 'unpack item', {'item'})
end_if(g, 'level > 3', {'level'})
build(g, {'xmlfile'}, 'wget url', {'url'})
build(g, {'pages', 'indexes'}, 'extract_from xml', {'xmlfile'})
update(g, {'queue'}, 'append indexes', {'indexes'})
update(g, {'allpages'}, 'append pages', {'pages'})
-- output(g, {'allpages'})
--]]

-- genius: *REBUILD*

--[[
# build url, level: queue.pop()
# gate level <= 3
# build xml: wget url
# build pages, indexes: extract_from xml
# update queue: append indexes
# update allpages: append pages
--]]

-- print_graph(g)
print('/*')
print(graph_to_str(g))
print('*/')
print(graph_to_dot(g))
