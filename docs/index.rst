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

To add in this step::

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


Adding a groupby step
---------------------

A commonly required operation is to perform summary operations over groups identified in the datasource.


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
