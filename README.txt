# ======== start of inlined base file base.ninja
rule touch
  command = touch $out

build file_that_always_exists.dummy: touch
build isroot: phony file_that_always_exists.dummy

rule nop
  command = true

rule makedir
  command = mkdir -p `dirname $out` && touch $out

rule makedirs
  command = mkdir -p world www.nytimes.com www.washingtonpost.com

rule wget
  command = curl -s -z $out -o $out https://`dirname $in`/robots.txt

rule extract_sitemaps_from_robots_txt
  command = cat $in | grep '^Sitemap: ' | sed -e 's/^Sitemap: //g' > $out

rule concat
  command = cat $in > $out

rule crawl_sitemaps
  #command = true
  command = ./crawl_sitemaps $in $out
# ======== end of inlined base file base.ninja

build root_sitemaps: python [line for line in root_sitemaps.txt]
build allpages: list
build queue: root_sitemaps
gate queue.length > 0
# build nextitem: queue.pop()
# build url, level: nextitem
build url, level: queue.pop()
gate level <= 3
build xml: wget url
build pages, indexes: extract_from xml
update queue: append indexes       # or updating an object causes all its deps to recompute? too confusing?
update allpages: append pages

# rebuild nextitem
rebuild url
rebuild level

build root_sitemaps: python [line for line in root_sitemaps.txt]
build allpages: list
build queue: root_sitemaps
gate queue.length > 0
# build nextitem: queue.pop()
# build url, level: nextitem
build url, level: queue.pop()
gate level <= 3
build xml: wget url
build pages, indexes: extract_from xml
build type1: compute_type1 indexes
build type2: compute_type2 type1
update queue: append type1       # or updating an object causes all its deps to recompute? too confusing?
update queue: append type2
update allpages: append pages

=============

build root_sitemaps: python [line for line in root_sitemaps.txt]
build allpages: python list
build subprogram: new Subprogram
build queue: root_sitemaps # the rule "set" is implied

gate queue.length > 0

# generate a ninja program to run all the pages in parallel

build url, level: queue.pop()
gate level <= 3

subprogram.build xml: wget url  # all input variables referred to are put in a closure "captured by value" in C++ terms.
subprogram.build pages, indexes: extract_from xml  # a separate copy of LHS vars is created: *NOT* captured.
update queue: append indexes # this will be serialized across all subprograms
update allpages: append pages # atomic with previous: all updates are carried out in *parallel* i.e. you need a "gate" to serialize operations.

# update queue: append indexes
# update allpage: append pages ; nop queue   # explicit dependency
# serialexec queue, allpage  # easier notation: the named outputs will not be updated in parallel. preceding steps can still proceed in parallel.

==============

# resize all images in a dir
build inputs: glob *.png
build options: 640x480
build operation: argv[1]

build outputs: python list

foreach-parallel input: inputs  # each iteration is a separate closure
  build s: new Subprogram
  s.build output: $operation input options
  update outputs: append {input, output}

return outputs

========================

# making this a subprogram

# resize all images in a dir
subprogram resizeimages

build $inputs: python list
self.build $options: 640x480
build operation: resize

build $outputs: python list

foreach-parallel input: inputs  # each iteration is a separate closure
  build s: new Subprogram
  s.build output: $operation input options  # compile-time error without the '$' prefix
  update outputs: append {input, output}

return outputs

end subprogram resizeimages

build outputs: run resizeimages
  override inputs: glob *.jpg
  override options: 1024x1024

return outputs: outputs

concisely:

return outputs: run resizeimages {inputs: glob *.jpg, options: 1024x1024}

or

run resizeimages {inputs: glob *.jpg, options: 1024x1024}

or simply:

resizeimages {inputs: glob *.jpg, options: 1024x1024}

w/ AI rewriting:

resizeimages *.jpg 1024x1024 becomes one of the things above. Perhaps by looking at what other invocations did.

Built-in types: Wildcard, Dimensions, Geometry?, Number, String, List<T> or just List?

formally:

return {outputs: run {f: resizeimages, args: {inputs: glob *.jpg, options: 1024x1024}}

===============

build www.washingtonpost.com/robots.txt.in: makedir
build www.washingtonpost.com/robots.txt: wget www.washingtonpost.com/robots.txt.inbuild www.washingtonpost.com/root_sitemaps.txt: extract_sitemaps_from_robots_txt www.washingtonpost.com/robots.txt
build www.washingtonpost.com/pages.txt: crawl_sitemaps www.washingtonpost.com/_sitemaps.txt
default www.washingtonpost.com/robots.txt.in

build www.nytimes.com/robots.txt.in: makedir
build www.nytimes.com/robots.txt: wget www.nytimes.com/robots.txt.in
build www.nytimes.com/root_sitemaps.txt: extract_sitemaps_from_robots_txt www.nytimes.com/robots.txt
build www.nytimes.com/pages.txt: crawl_sitemaps www.nytimes.com/root_sitemaps.txt
default www.nytimes.com/robots.txt.in

build www.uspto.gov/robots.txt.in: makedir
build www.uspto.gov/robots.txt: wget www.uspto.gov/robots.txt.in
build www.uspto.gov/root_sitemaps.txt: extract_sitemaps_from_robots_txt www.uspto.gov/robots.txt
build www.uspto.gov/pages.txt: crawl_sitemaps www.uspto.gov/root_sitemaps.txt
default www.uspto.gov/robots.txt.in

build world/pages.txt.in: makedir
build world/pages.txt: concat www.washingtonpost.com/pages.txt www.nytimes.com/pages.txt www.uspto.gov/pages.txt
build world/root_sitemaps.txt: concat www.washingtonpost.com/root_sitemaps.txt www.nytimes.com/root_sitemaps.txt www.uspto.gov/root_sitemaps.txt
