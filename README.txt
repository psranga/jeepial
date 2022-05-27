----------------------------------------------------
05/27 Data Model
----------------------------------------------------

-- mono --
operation dst1, dst2, ..., dstn: code

'code' produces:

  a *list* of values for its destinations (ok if some dsts dont get values)

values produced by one code for multiple dsts: *zipped* (python zip)
values produced by different codes for different dsts: *cross-product*

*Order of lines is significant*.

---------------------------------------------------
Topo sort
---------------------------------------------------

Keep the symbolic version of level for each inedge.
"Collapse" when all inedges visited.

Rename the ones that have self-loops as indicated by
the symbols.

A node is "resolved" when all inedges have resolved levels.
An inedge's level is resolved if the node on which its level is based is resolved.

Roots are resolved and have level 0.

-- single-quoted = mono
-- indented = indented
-- numbered = numbered
