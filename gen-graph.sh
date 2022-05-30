#!/bin/bash

set -e
set -x

lua l2.lua $p.txt $p.lua $p.gv $p.0.gv 2>&1

dot -Tpdf $p.gv -o$p.1.pdf
dot -Tpdf $p.0.gv -o$p.0.pdf

#dot -Tps $p.0.gv -o>(ps2ps -sPAPERSIZE=letter - - | ps2pdf - $p.0.pdf)
#dot -Tps $p.gv -o>(ps2ps -sPAPERSIZE=letter - - | ps2pdf - $p.pdf)

#grep '^-- ' $p.lua | a2ps --border=0 -B -l 40 -R -o- | ps2pdf - $p.ovl.pdf
grep '^-- ' $p.lua | a2ps --border=0 -B --columns=1 -l 100 -R -o- | ps2ps -sPAPERSIZE=letter - - | ps2pdf - $p.ovl.pdf

qpdf --overlay $p.ovl.pdf --repeat=1 -- --empty --pages $p.0.pdf $p.1.pdf -- >(pdftops -paper letter -expand - - | ps2pdf - $p.c.pdf)
