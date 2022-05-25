local sgl = require('sgl')

function main(g)
end

local args = {}

function setargs(l)
  args = l
end

function argv(i)
  return argv[i]
end

function write_as_lines_to_file ()
end

function new_program()
end

function init()
end

function input()
end

function output()
end

function ggoto()
end

function build()
end

function pbuild()
end

function update()
end

function run()
end

function new_debug()
  return {}
end

function new_code()
  return {}
end

function new_program()
  -- local pg = {dsts = {}, deps = {}, code = new_code(), g = sgl.new_sg()}
  local pg = {code_by_line = {}, g = sgl.new_sg(), debug_info = {}}
  return pg
end

function init(pg, t)
  local code_by_line = pg.code_by_line
  local g = pg.g
  local debug_info = g.debug_info

  code_by_line[#code_by_line+1] = t.code
  debug_info[#1+debug_info] = {dsts=t.dsts, code=t.code, deps=t.deps}

  -- execute the code
end

function input(pg, t)
  local code_by_line = pg.code_by_line
  local g = pg.g
  local debug_info = g.debug_info

  code_by_line[#code_by_line+1] = t.code

  for i, dst in t.dsts do
    for j, dep in t.deps do
      assert not pg.g.edge_exists(g, dep, dst)
      local edge_info = pg.g.add_edge(dep, dst)
      edge_info[1+#edge_info] = {operation='input', code=t.code, linenum=#code_by_line}
    end
  end

  debug_info[#1+debug_info] = {dsts=t.dsts, code=t.code, deps=t.deps}
end

function output(pg, t)
  local code_by_line = pg.code_by_line
  local g = pg.g
  local debug_info = g.debug_info

  code_by_line[#code_by_line+1] = t.code

  for i, dst in t.dsts do
    for j, dep in t.deps do
      local edge_info = pg.g.add_edge(dep, dst)
      edge_info[1+#edge_info] = {operation='output', code=t.code, linenum=#code_by_line}
    end
  end

  debug_info[#1+debug_info] = {dsts=t.dsts, code=t.code, deps=t.deps}
end

function build(pg, t)
  local code_by_line = pg.code_by_line
  local g = pg.g
  local debug_info = g.debug_info

  code_by_line[#code_by_line+1] = t.code

  for i, dst in t.dsts do
    for j, dep in t.deps do
      local edge_info = pg.g.add_edge(dep, dst)
      edge_info[1+#edge_info] = {operation='build', code=t.code, linenum=#code_by_line}
    end
  end

  debug_info[#1+debug_info] = {dsts=t.dsts, code=t.code, deps=t.deps}
end

l2rtl = {
  new_program = new_program,
  init = init,
  input = input,
  output = output,
  ggoto = ggoto,
  build = build,
  pbuild = pbuild,
  update = update,
  run = run
}

