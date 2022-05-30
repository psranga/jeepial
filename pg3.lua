-- 1 init : l2dofile ('crawl_sitemaps.lua')
-- 2 init : set_argv ('roots_site1.txt', 'pages.txt')
-- 3 input root_sitemapstxt: argv(1)
-- 4 output write_allpages: write_as_lines_to_file ( argv(2) , gx.allpages )
-- 5 build root_sitemaps: lines_in_file ( gx.root_sitemapstxt )
-- 6 build level: constant( 0 )
-- 7 pbuild url: unpack ( gx.root_sitemaps )
-- 8 precondition xml: onlyif ( cmp_le, gx.level, 2 )
-- 9 build xml: wget ( gx.url )
-- 10 update level_from_level: add ( gx.level, 1 ) or gx.xml
-- 11 build pages, indexes: process_one_sitemap ( gx.xml )
-- 12 pbuild url_from_indexes: unpack ( gx.indexes )
-- 13 pbuild page: unpack ( gx.pages )
-- 14 update allpages: append ( gx.page )
-- rename_infos: {rename_infos=((level, level_from_level, 10), (url, url_from_indexes, 12))}
dofile('run.lua')
dofile('l2rtl.lua')
g = {lines={
  {linenum=1, operation='init',
  code=[[l2dofile ('crawl_sitemaps.lua')]],
  dsts={}, deps={[[START]]}},

  {linenum=2, operation='init',
  code=[[set_argv ('roots_site1.txt', 'pages.txt')]],
  dsts={}, deps={[[START]]}},

  {linenum=3, operation='input',
  code=[[argv(1)]],
  dsts={[[root_sitemapstxt]]}, deps={[[START]]}},

  {linenum=4, operation='output',
  code=[[write_as_lines_to_file ( argv(2) , gx.allpages )]],
  dsts={[[write_allpages]]}, deps={[[allpages]]}},

  {linenum=5, operation='build',
  code=[[lines_in_file ( gx.root_sitemapstxt )]],
  dsts={[[root_sitemaps]]}, deps={[[root_sitemapstxt]]}},

  {linenum=6, operation='build',
  code=[[constant( 0 )]],
  dsts={[[level]]}, deps={[[START]]}},

  {linenum=7, operation='pbuild',
  code=[[unpack ( gx.root_sitemaps )]],
  dsts={[[url]]}, deps={[[root_sitemaps]]}},

  {linenum=8, operation='precondition',
  code=[[onlyif ( cmp_le, gx.level, 2 )]],
  dsts={[[xml]]}, deps={[[level]]}},

  {linenum=9, operation='build',
  code=[[wget ( gx.url )]],
  dsts={[[xml]]}, deps={[[url]]}},

  {linenum=10, operation='update',
  code=[[add ( gx.level, 1 ) or gx.xml]],
  dsts={[[level_from_level]]}, deps={[[level]], [[xml]]}},

  {linenum=11, operation='build',
  code=[[process_one_sitemap ( gx.xml )]],
  dsts={[[pages]], [[indexes]]}, deps={[[xml]]}},

  {linenum=12, operation='pbuild',
  code=[[unpack ( gx.indexes )]],
  dsts={[[url_from_indexes]]}, deps={[[indexes]]}},

  {linenum=13, operation='pbuild',
  code=[[unpack ( gx.pages )]],
  dsts={[[page]]}, deps={[[pages]]}},

  {linenum=14, operation='update',
  code=[[append ( gx.page )]],
  dsts={[[allpages]]}, deps={[[page]]}}
}}
run_program(g)
