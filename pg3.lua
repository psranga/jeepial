-- 1 init : l2dofile ('crawl_sitemaps.lua')
-- 2 init : set_argv ('roots_site1.txt', 'all_article_urls.txt')
-- 3 input root_sitemapsfn: argv(1)
-- 4 output write_allpages: write_as_lines_to_file ( argv(2) , gx.all_article_urls )
-- 5 build root_sitemap_urls: lines_in_file ( gx.root_sitemapsfn )
-- 6 build level: constant( 0 )
-- 7 pbuild sitemap_url: unpack ( gx.root_sitemap_urls )
-- 8 precondition sitemap_xml: onlyif ( cmp_le, gx.level, 2 )
-- 9 build sitemap_xml: wget ( gx.sitemap_url )
-- 10 update level_from_level: add ( gx.level, 1 ) or gx.sitemap_xml
-- 11 build article_urls, sitemap_urls: process_one_sitemap ( gx.sitemap_xml )
-- 12 pbuild sitemap_url_from_sitemap_urls: unpack ( gx.sitemap_urls )
-- 13 pbuild article_url: unpack ( gx.article_urls )
-- 14 update all_article_urls: append ( gx.article_url )
-- rename_infos: {rename_infos=((level, level_from_level, 10), (sitemap_url, sitemap_url_from_sitemap_urls, 12))}
dofile('run.lua')
dofile('l2rtl.lua')
g = {lines={
  {linenum=1, operation='init',
  code=[[l2dofile ('crawl_sitemaps.lua')]],
  dsts={}, deps={[[START]]}},

  {linenum=2, operation='init',
  code=[[set_argv ('roots_site1.txt', 'all_article_urls.txt')]],
  dsts={}, deps={[[START]]}},

  {linenum=3, operation='input',
  code=[[argv(1)]],
  dsts={[[root_sitemapsfn]]}, deps={[[START]]}},

  {linenum=4, operation='output',
  code=[[write_as_lines_to_file ( argv(2) , gx.all_article_urls )]],
  dsts={[[write_allpages]]}, deps={[[all_article_urls]]}},

  {linenum=5, operation='build',
  code=[[lines_in_file ( gx.root_sitemapsfn )]],
  dsts={[[root_sitemap_urls]]}, deps={[[root_sitemapsfn]]}},

  {linenum=6, operation='build',
  code=[[constant( 0 )]],
  dsts={[[level]]}, deps={[[START]]}},

  {linenum=7, operation='pbuild',
  code=[[unpack ( gx.root_sitemap_urls )]],
  dsts={[[sitemap_url]]}, deps={[[root_sitemap_urls]]}},

  {linenum=8, operation='precondition',
  code=[[onlyif ( cmp_le, gx.level, 2 )]],
  dsts={[[sitemap_xml]]}, deps={[[level]]}},

  {linenum=9, operation='build',
  code=[[wget ( gx.sitemap_url )]],
  dsts={[[sitemap_xml]]}, deps={[[sitemap_url]]}},

  {linenum=10, operation='update',
  code=[[add ( gx.level, 1 ) or gx.sitemap_xml]],
  dsts={[[level_from_level]]}, deps={[[level]], [[sitemap_xml]]}},

  {linenum=11, operation='build',
  code=[[process_one_sitemap ( gx.sitemap_xml )]],
  dsts={[[article_urls]], [[sitemap_urls]]}, deps={[[sitemap_xml]]}},

  {linenum=12, operation='pbuild',
  code=[[unpack ( gx.sitemap_urls )]],
  dsts={[[sitemap_url_from_sitemap_urls]]}, deps={[[sitemap_urls]]}},

  {linenum=13, operation='pbuild',
  code=[[unpack ( gx.article_urls )]],
  dsts={[[article_url]]}, deps={[[article_urls]]}},

  {linenum=14, operation='update',
  code=[[append ( gx.article_url )]],
  dsts={[[all_article_urls]]}, deps={[[article_url]]}}
}}
run_program(g)
