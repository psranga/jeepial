-- functions like set_argv for the l2 sandbox.

dofile('stdlib.lua')

l2args = {}

function set_argv(t)
  assert(is_seq(t))
  l2args = map(t, function(x) assert(type(x) == 'string'); return '' .. x end) -- coerce to string
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
  local r = {}
  local fh = io.open(fn)
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
  return boxed(x) -- see boxed and incr below
end

function unpack(l)
  assert(is_seq(l))
  return l
end

function cmp(lhs, opfn, rhs)
  return opfn(lhs, rhs)
end

function cmp_gt(lhs, rhs) return lhs < rhs end
function cmp_ge(lhs, rhs) return lhs >= rhs end
function cmp_eq(lhs, rhs) return lhs == rhs end
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
  return bind_back(table.insert, x) -- closure
end

function incr(n)
  return bind_back(function(t) t[1] = t[1] + n end, n) -- closure
end

