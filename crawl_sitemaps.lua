function wget(url)
  dlog('wget')
  return 'xmltext'
end

function process_one_sitemap(xmltext)
  dlog('process_one_sitemap')
  local pages = {'p1.txt', 'p2.txt', 'p3.txt'}
  local indexes = {'s1.txt', 's2.txt', 's3.txt'}
  return pages, indexes
end
