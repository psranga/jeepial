(work in progress)

# MOTIVATION/GENESIS

- Why is this important
- What was the result
- What pain-point/problem are we solving

# ABSTRACT

# SALES PITCH

- Jeepial (which tentatively stands for Glue/Graph Programming Language) is an
  experimental DSL/programming language that resembles software build tools'
  syntax, that is designed to enable power end-users to leverage single-machine
  parallelism for ad hoc processing of medium-size datasets (e.g., sub-TB, not
  PB i.e. think spreadsheets not RDBMS)

- The Jeepial programming model is designed to make it so the same specification
  can be trivially adapted to become a continuously-running workflow.

- Jeepial strives to be easier for a power user to work with than standard Unix
  tools like xargs, find, parallel.

- The sweet spot would be things like:

  + an "RSS reader" that creates keyword-based custom alerts that get emailed to the user,
  + a workflow that prints on the user's printer the daily New York Times crossword,
  + running multiple variations on some task (perhaps to select the most pleasing one?)
  + image processing tasks like reducing color ink usage when printing *web articles*
    by increasing dithering of images in PDFs.
    I actually did this, and I felt something like Jeepial would have helped during the interactive
    prototyping phase. TLDR: split PDFs into high-res images, divide the image into
    approx 64x64 pixel tiles, for each tile convert RGB to CMYK color space and output the average
    CMYK per tile. This value is quite literally a proxy for the amount of ink the
    inkjet printer will lay down. Use a heuristic that the top 20% of "ink intensities"
    are "excessive" and should be munged to use half the ink.

- Jeepial prioritizes "ergonomic" factors over efficiency when they conflict. Factors
  such as understandability of the programming model, "guessable" semantics,
  "getting it right with fewer iterations".

## Why this is useful

Power efficiency: As more and more machines (including phones) ship with
"high-efficiency" slow ultra-low-power cores, parallelism will become even more
important.

Desktop cores are likely underused: People's time is being wasted because it's
simply too much work to reliabliy create ad hoc parallel workflows.

Fun: It's an interesting design exercise.

# INTRODUCTION

# EXAMPLES

This is a Jeepial program that crawls some websites' sitemaps [sitemap files
can specify more sitemap URLs to also be crawled].

The syntax is heavily inspired by the Ninja software build tool. Each
Jeepial line has this syntax:

   OPERATION outputs: code-fragment

E.g.,

   build article_urls, new_sitemap_urls: process_one_sitemap(url)

This says that two outputs named 'article_urls' and 'new_sitemap_urls' will
be created when the code process_one_sitemap() is called with the value of
previously-generated output named 'url' as its input.

    input root_sitemapsfn: argv(1)

    build root_sitemap_urls: lines_in_file (root_sitemapsfn)
    build level: constant(0)

    pbuild sitemap_url: unpack(root_sitemap_urls)

    precondition sitemap_xml: if level < 3
    build sitemap_xml: wget(sitemap_url)
    update level: level + 1

    build article_urls, sitemap_urls: process_one_sitemap(sitemap_xml)

    pbuild sitemap_url: unpack(sitemap_urls)

    pbuild article_url: unpack(article_urls)
    update all_article_urls: append(article_url)

    output write_allpages: write_as_lines_to_file(argv(2), all_article_urls)

# PROGRAMMING MODEL

Is optimized for `subdivide -> recursive solve -> assemble` type tasks.

Use Make-like syntax to specify a graph (which can be cyclic), whose nodes
are the "outputs" specified in Jeepial, and edges are the code fragments.

So `build root_sitemap_urls: lines_in_file(root_sitemaps_fn)`, would
result in two nodes, named `root_sitemap_urls` and `root_sitemaps_fn` with a
*directed* edge going *from* `root_sitemaps_fn` *to* `root_sitemap_urls`, with edge
being labeled `lines_in_file(root_sitemaps_fn)`.

And quite literally, a Lua function named 'lines_in_file' gets called. And
quite literally the return value of that function is put inside a Lua table
(hash) under the key 'root_sitemap_urls'. And again, quite literally the
function 'lines_in_file' is called with the value from a Lua table under the
key 'root_sitemaps_fn' [which should have been previously set].

Very similar to make, with Lua instead of shell. Except that Jeepial "provides
batteries" so common operations like 'lines_in_file' are rigorously defined and
well-documented.

The parallelism happens when the operations "pbuild" and "unpack" happen.

# PROGRAMMING MODEL

## Simplifying Assumptions

### Shared Variables


# WHY JEEPIAL LOOKS TO BUILD TOOLS

Build tools have a long history of using single-machine parallelism to speed things up.

And build tools are heavily used, so the syntax and concepts from those
languages are well-knowns.

And for the next set of power-user things (checkpointing, caching etc), I have
a hunch build tools' learnings from reproducible builds is going to be useful.

# IMPLEMENTATION

# RESULTS


