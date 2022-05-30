-- functions like set_argv for the l2 sandbox.

dofile('stdlib.lua')

l2args = {}

function l2dofile(fn)
  dofile(fn)
  return nil
end

function set_argv(...)
  l2args = {}
  for i = 1, select('#', ...) do
    local arg = select(i, ...)
    assert(type(arg) == 'string')
    table.insert(l2args, arg)
  end
  return nil
end

function argv(i)
  assert(i >= 1 and i <= #l2args)
  return l2args[i]
end

function write_as_lines_to_file(fn, l)
  local fh = io.open(fn, 'w+')
  for i, v in #ls do
    fh:write(v, '\n')
  end
  fh:close()
end

function lines_in_file(fn, l)
  local me = 'lines_in_file'
  local r = {}
  dlog(me, 'fn=', fn)
  dlog(me, ' within lines_in_file:', gx)
  local fh = io.open(fn)
  assert(fh ~= nil)
  while true do
    local s = fh:read()
    if not s then break end
    table.insert(r, s)
  end
  return r
end

function constant(x)
  assert(type(x) ~= 'table') -- anything else passed by reference?
  assert(type(x) ~= 'function') -- anything else passed by reference?
  -- return boxed(x) -- see boxed and incr below
  return x
end

function add(v, n)
  return v + n
end

function unpack(l)
  assert(is_seq(l))
  return l
end

--[[
function cmp_le(lhs, rhs)
  return function
    assert(is_box_with_value(lhs))
    return lhs[1] <= rhs
  end
end
--]]

function onlyif(opfn, lhs, rhs)
  -- true iff conditionfn == true
  function do_onlyif()
    if opfn(lhs, rhs) == true then
      return true
    else
      return false
    end
  end

  return do_onlyif()
end

--function docmp_gt(lhs, rhs) return lhs < rhs end
--function docmp_ge(lhs, rhs) return lhs >= rhs end
--function docmp_eq(lhs, rhs) return lhs == rhs end
function cmp_le(lhs, rhs) return lhs <= rhs end

function boxed(x)
  assert(type(x) == 'string' or type(x) == 'number')
  return box_with_value(x)
end

function is_box_with_value(t)
  assert(#t == 1)
  assert(is_seq(t))
  local x = t[1]
  assert(type(x) == 'string' or type(x) == 'number')
  return true
end

function box_with_value(x)
  return {x}
end

-- For functions that be called only for updates i.e., they have side effects
--   in the next epoch.
-- returns a function that takes *ONE* argument. the caller sets the first argument
-- and calls the function returned from here. That will cause the side-effect
-- to happen.

function append(x)
  return bind_back(table.insert, x) -- not a closure. my name is captured in table.insert.
end

function incr(n)
  function doincr(b, x)
    -- the number to be incremented has to be boxed inside a table.
    b[1] = b[1] + x
  end

  return bind_back(doincr, n) -- technically not a closure. my name is captured by calling doincr.
end

