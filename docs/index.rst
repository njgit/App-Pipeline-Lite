.. pipelite documentation master file, created by
   sphinx-quickstart on Fri Nov 21 12:03:55 2014.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Welcome to Pipelite's documentation!
===================================

*Pipelite* is a lightweight workflow system developed in a bioinformatics context. 

**Contents:**

.. toctree::
   :maxdepth: 2

   index.rst


Installation
============

Download the Pipelite executable - **plite**, and an associated dispatcher - **dispatch-basic**::

     wget -O plite https://github.com/njgit/App-Pipeline-Lite/blob/master/bin/packed/plite?raw=true
     wget -O dispatch-basic https://github.com/njgit/App-Pipeline-Lite/blob/master/bin/packed/dispatch-basic?raw=true
     chmod 755 plite
     chmod 755 dispatch-basic

Add plite to your PATH in someway - e.g. move plite to a bin directory such as ~/bin

To configure the system run::

    plite vsc --editor vim

Where "vim" can be replaced by your favourite editor. This will open a config file with one line - a configuration variable for the current editor.
Add the following line to set the dispatcher::

    dispatcher=/path/to/dispatch-basic

Where /path/to is substituted with the real path to dispatch-basic.


Quick Start
===========

A Single Step Pipeline
----------------------

Lets say you have a command that prints a sequence of numbers, filters some out and writes to a file::

    seq 10 | egrep -v '5|6' > filterseq.txt

And you want to seq for **N** different values, and **filter** on different numbers - as listed in 
a table 

+-------+-------------+-------+------------+
| N     | filter      | group |   name     |
+=======+=============+=======+============+
| 12    |  5\|6       |  A    |    james   |
+-------+-------------+-------+------------+
| 15    |  7\|8       |  B    |    nozomi  |
+-------+-------------+-------+------------+
| 16    |  9\|10      |  A    |    ryan    |
+-------+-------------+-------+------------+
| 20    |  12\|13     |  B    |    tiffiny |
+-------+-------------+-------+------------+

Create a new pipeline directory and a set of skeleton files::

    plite new filter-seq

View the default pipeline file located in filter-seq/filter-seq.pipeline::

    plite vp filter-seq

This consists of one line, showing how the command has been made into a "template"
that can be run over each row of the datasource. A step starts with the name of the step
followed by a dot::

    seq. seq [% datasource.N %] | egrep -v '[% datasource.filter %]' > [% seq.filterseq.txt %]

Take a look at the "datasource" for the pipeline - corresponding to the table above::

    less filter-seq/filter-seq.datasource

Run the single step pipeline over the datasource::

    plite run filter-seq

Check the output files::

    tree filter-seq/output
    filter-seq/output
    └── run1
        ├── job0
        │       └── seq
        │       ├── err
        │       └── filterseq.txt
        ├── job1
        │   └── seq
        │       ├── err
        │       └── filterseq.txt
        ├── job2
        │   └── seq
        │       ├── err
        │       └── filterseq.txt
        ├── job3
        │   └── seq
        │       ├── err
        │       └── filterseq.txt
        └── settings
            └── 1
                ├── filter-seq.datasource
                ├── filter-seq.graph.yaml
                └── filter-seq.pipeline



Symlink recognisable identifiers from the datasource to the pipeline files::

    plite symlink -f name filter-seq
    tree filter-seq/symlink/
    filter-seq/symlink/
    └── seq
        └── 1
            ├── james-err -> /filter-seq/output/run1/job0/seq/err
            ├── james-filterseq.txt -> /filter-seq/output/run1/job0/seq/filterseq.txt
            ├── nozomi-err -> /filter-seq/output/run1/job1/seq/err
            ├── nozomi-filterseq.txt -> /filter-seq/output/run1/job1/seq/filterseq.txt
            ├── ryan-err -> /filter-seq/output/run1/job2/seq/err
            ├── ryan-filterseq.txt -> /filter-seq/output/run1/job2/seq/filterseq.txt
            ├── tiffiny-err -> /filter-seq/output/run1/job3/seq/err
            └── tiffiny-filterseq.txt -> /filter-seq/output/run1/job3/seq/filterseq.txt


Check the raw "command" file using::

    plite vg feature-seq

If you don't want to actually dispatch the pipeline(execute the commands), then
use the -m switch (or --smoke-test)::


     plite run -m filter-seq


This still produces the raw "command file" that allows you to inspect what will be run.


Adding more steps
-----------------

We can add another step that takes the output of the seq. step and counts the number of characters in that file.

Edit the pipeline file::

    plite vp filter-seq

To add in the count-chars step as below::

    seq. seq [% datasource.N %] | egrep -v '[% datasource.filter %]' > [% seq.filterseq.txt %]

    count-chars. wc [% seq.filterseq.txt %] > [% count-chars.char.count %]


Run the pipeline::

    plite run filter-seq

**Plite** will ensure that the count-char step is run after the seq step.  

The output directory tree now has a second "run" (run2) using the modified pipeline. The output tree now looks like this::

    filter-seq/output
    ├── run1
    │   ├── job0
    │   │   └── seq
    │   │       ├── err
    │   │       └── filterseq.txt
    │   ├── job1
    │   │   └── seq
    │   │       ├── err
    │   │       └── filterseq.txt
    │   ├── job2
    │   │   └── seq
    │   │       ├── err
    │   │       └── filterseq.txt
    │   ├── job3
    │   │   └── seq
    │   │       ├── err
    │   │       └── filterseq.txt
    │   └── settings
    │       └── 1
    │           ├── filter-seq.datasource
    │           ├── filter-seq.graph.yaml
    │           └── filter-seq.pipeline
    └── run2
        ├── job0
        │   ├── count-chars
        │   │   ├── char.count
        │   │   └── err
        │   └── seq
        │       ├── err
        │       └── filterseq.txt
        ├── job1
        │   ├── count-chars
        │   │   ├── char.count
        │   │   └── err
        │   └── seq
        │       ├── err
        │       └── filterseq.txt
        ├── job2
        │   ├── count-chars
        │   │   ├── char.count
        │   │   └── err
        │   └── seq
        │       ├── err
        │       └── filterseq.txt
        ├── job3
        │   ├── count-chars
        │   │   ├── char.count
        │   │   └── err
        │   └── seq
        │       ├── err
        │       └── filterseq.txt
        └── settings
            └── 1
                ├── filter-seq.datasource
                ├── filter-seq.graph.yaml
                └── filter-seq.pipeline


Summarising over all jobs using a once step
-------------------------------------------

A common task is to perform a summary over all of the output of a previous step, or perhaps all values of a datasource.
For example, counting the total number of characters in all of the filterseq.txt files produced in the seq step
of the filter-seq pipeline.

This can be achieved by adding a step that executes only once, and for which you can access the path names of 
all the filterseq.txt files.

Edit the pipeline file::

    plite vp filter-seq

Add a step that counts characters over all the filterseq.txt files::

    seq. seq [% datasource.N %] | egrep -v '[% datasource.filter %]' > [% seq.filterseq.txt %]

    count-chars. wc [% seq.filterseq.txt %] > [% count-chars.char.count %]

    count-all-chars.once wc [% jobs.seq.filterseq.txt %] > [% count-all-chars.sum.txt %]

By prepending the "jobs" keyword to the file reference "seq.filterseq.txt" in [% jobs.seq.filterseq.txt %] substitutes the names of all the filterseq.txt files produced from the seq step. 

The output tree looks like::

    └── run3
        ├── job0
        │   ├── count-all-chars
        │   │   ├── err
        │   │   └── sum.txt
        │   ├── count-chars
        │   │   ├── char.count
        │   │   └── err
        │   └── seq
        │       ├── err
        │       └── filterseq.txt
        ├── job1
        │   ├── count-chars
        │   │   ├── char.count
        │   │   └── err
        │   └── seq
        │       ├── err
        │       └── filterseq.txt
        ├── job2
        │   ├── count-chars
        │   │   ├── char.count
        │   │   └── err
        │   └── seq
        │       ├── err
        │       └── filterseq.txt
        ├── job3
        │   ├── count-chars
        │   │   ├── char.count
        │   │   └── err
        │   └── seq
        │       ├── err
        │       └── filterseq.txt
        └── settings
             └── 1
                 ├── filter-seq.datasource
                 ├── filter-seq.graph.yaml
                 └── filter-seq.pipeline



Adding a groupby step
---------------------

A commonly required task is to perform summary operations over groups identified in the datasource. This is
achieved using a groupby step that will substitute the filenames or values from the datasource or another step
according to groups specified in the datasource.


Let's say we want to concatenate the output files from the seq step together according to the group field specified in the
datasource above. So the filter.txt files for james and ryan who are in group A should be concatenated together, and the files
in group B ( nozomi and tiffiny ) should be concatenated together also.

Modify the pipeline file::

    plite vp filter-seq

Include a new step called concat-seq::

    seq. seq [% datasource.N %] | egrep -v '[% datasource.filter %]' > [% seq.filterseq.txt %]

    count-chars. wc -l [% seq.filterseq.txt %] > [% count-chars.char.count %]

    concat-seq.groupby.group cat [% groupby.group.seq.filterseq.txt %] > [% concat-seq.filterseq-group.txt %]

This command will effectively replace [% groupby.group.seq.filterseq.txt %] with the filterseq.txt files of each group with a space between them.

So the groupby command on running the pipeline (if the pipeline was created in your home directory) would produce two commands like this::

    cat ~/filter-seq/output/run3/job0/seq/filterseq.txt ~/filter-seq/output/run3/job2/seq/filterseq.txt > ~/filter-seq/output/run3/job0/concat-seq/filterseq-group.txt 
    cat ~/filter-seq/output/run3/job1/seq/filterseq.txt ~/filter-seq/output/run3/job3/seq/filterseq.txt > ~/filter-seq/output/run3/job1/concat-seq/filterseq-group.txt

job0 and job2 correspond to group A in the first command, and job1 and job3 correspond to group B. 

Since there are only two groups, only two files will be produced that are relevant, and they will go into the first two job directories. As can be seen, the order is
determined by the first occurrence of the group value in the datasource.


The output tree focused on run4 shows that just the first two jobs have relevant data:: 

    run4
        ├── job0
        │   ├── concat-seq
        │   │   ├── err
        │   │   └── filterseq-group.txt
        │   ├── count-chars
        │   │   ├── char.count
        │   │   └── err
        │   └── seq
        │       ├── err
        │       └── filterseq.txt
        ├── job1
        │   ├── concat-seq
        │   │   ├── err
        │   │   └── filterseq-group.txt
        │   ├── count-chars
        │   │   ├── char.count
        │   │   └── err
        │   └── seq
        │       ├── err
        │       └── filterseq.txt
        ├── job2
        │   ├── concat-seq
        │   ├── count-chars
        │   │   ├── char.count
        │   │   └── err
        │   └── seq
        │       ├── err
        │       └── filterseq.txt
        ├── job3
        │   ├── concat-seq
        │   ├── count-chars
        │   │   ├── char.count
        │   │   └── err
        │   └── seq
        │       ├── err
        │       └── filterseq.txt
        └── settings
            └── 1
                 ├── filter-seq.datasource
                 ├── filter-seq.graph.yaml
                 └── filter-seq.pipeline



The Datasource
==============




Steps
=====


Basic Step
----------


Step Conditions
---------------


Configuration
=============


prepend error
-------------


append command
--------------


Pipelite Structure
==================


Parsing
-------


Resolving
---------


Dependency Resolution
---------------------


Dispatcher
-----------



..   Indices and tables
..   ==================
..  * :ref:`genindex`
..  * :ref:`modindex`
..  * :ref:`search`
