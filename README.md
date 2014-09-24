Pipelite (App-Pipeline-Lite)
=================

Pipelite is still in an experimental phase - Pre Alpha would be the best description.

Installation
============
Download the Pipelite executable - "plite" and an associated dispatcher dispatch-basic

```bash
wget -O plite https://github.com/njgit/App-Pipeline-Lite/blob/doc-feature/bin/packed/plite?raw=true
wget -O dispatch-basic https://raw.githubusercontent.com/njgit/App-Pipeline-Lite/master/bin/packed/dispatch-basic

chmod 755 plite
chmod 755 dispatch-basic
```

The best thing to do is to add plite to your PATH 

Then run:

```bash 
plite vsc --editor vim
```
where "vim" could be replaced with your favourite editor. This will open a config file with one line, 
showing you the config file, which contains one setting - the config variable "editor" set to the current editor. 

Add the following line to set the dispatcher

```bash
dispatcher=/path/to/dispatch-basic
```

where /path/to is substituted with the actual path to dispatch-basic.


Basic Usage
===========
The following is a "hello world" for Pipelite.
Lets say you have a command that prints a sequence of numbers, filters some out and writes to a file:

```
seq 10 | grep -v '5|6' > filterseq.txt  
```

And you want to seq for different values, and you want to filter on different numbers - as listed in 
a table 
| N        | Are           | Cool  |
| ------------- |:-------------:| -----:|
| col 3 is      | right-aligned | $1600 |
| col 2 is      | centered      |   $12 |
| zebra stripes | are neat      |    $1 |

|N     | filter | group|   name
|------|--------|------|-----------
|12    |  5\|6   |  A   |    james
|15    |  7\|8   |  B   |    nozomi
|16    |  9\|10  |  A   |    ryan
|20    |  12\|13 |  B   |    tiffiny

Creates a new pipeline directory and a set of skeleton files.
```bash
plite new filter-seq
```
 views the default pipeline file located in filter-seq/filter-seq.pipeline
```bash
plite vp filter-seq
```
 take a look at the "datasource" for the pipeline. 

```bash
less filter-seq/filter-seq.datasource
```
  run the single step pipeline over the datasource
```bash
plite run filter-seq
```
Take a look at the output files
```
tree filter-seq/output
filter-seq/output
└── run1
    ├── job0
    │   └── seq
    │       ├── err
    │       └── filterseq.txt
    ├── job1
    │   └── seq
    │       ├── err
    │       └── filterseq.txt
    ├── job2
    │   └── seq
    │       ├── err
    │       └── filterseq.txt
    ├── job3
    │   └── seq
    │       ├── err
    │       └── filterseq.txt
    └── settings
        └── 1
            ├── filter-seq.datasource
            ├── filter-seq.graph.yaml
            └── filter-seq.pipeline

```
  symlink recognisable identifiers from the datasource to the pipeline files
```bash
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
```

Check the raw "command" file using 

```bash
plite vg feature-seq
```

If you don't want to actually dispatch(execute the commands) the pipeline, then
use the -m switch (or --smoke-test)

```bash
plite run -m filter-seq
```

This still produces the raw "command file" that allows you to inspect what will be run.


Pipeline and Datasource Specification
=====================================

This is a list of things that currently will not be warned against, but which will result 
in strange behaviour (they will be removed from the list as updates are made to warn or 
allow the behaviour):

* No dots in datasource names - underscores and hyphens are ok 
  (i.e. no column name "file.gz", use "file-gz" instead)
* The datasource must be tab delimited
* No blank lines at the beginning of a pipeline file

Dispatchers
===========
The dispatch-basic dispatcher is mainly for demonstration and does not offer parallelisation.
A dispatcher for Platform LSF wil be added soon (contact me if you want to use this right
away) and other dispatchers targeted to various job management systems are on the todo.

Further Documentation
=====================
This will be added soon, along with some typical bioinformatic pipeline examples.
