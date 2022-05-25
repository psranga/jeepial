function new_sg()
  g = {edges = {}, nodes={}, nodes_by_name={}}
  update_node_list(g)
end

function node_exists(g, src)
  return #g.nodes <= src
end

function get_node(g, src)
  return g.nodes[src]
end

function node_exists_by_name(g, srcn)
  return g.nodes_by_name[srcn]
end

function get_node_by_name(g, srcn)
  return g.nodes[g.nodes_by_name[srcn]]
end

function get_or_add_node(g, srcn)
  local nodes = g.nodes
  local nodes_by_name = g.nodes_by_name
  local edges = g.edges

  if not nodes_by_name[srcn] then
    nodes[#nodes+1] = srcn
    local src = #nodes
    nodes_by_name[srcn] = src
    if not edges[src] then edges[src] = {} end
  end
  return nodes_by_name[srcn]
end

function edge_exists(g, srcn, dstn)
  local src = get_node_by_name(srcn)
  local dst = get_node_by_name(dstn)
  local r = (not (g.edges[src] == nil)) and (not (g.edges[src][dst] == nil))
  return r
end

function add_edge(g, srcn, dstn)
  local src = get_or_add_node(srcn)
  local dst = get_or_add_node(dstn)
  if g.edges[src][dst] == nil then
    g.edges[src][dst] = {}
  end
  return g.edges[src][dst]
end

function rm_edge(g, srcn, dstn)
  local src = get_or_add_node(srcn)
  local dst = get_or_add_node(dstn)
  g.edges[src][dst] = nil
end

