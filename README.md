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

Add the path to plite to your PATH 

Then run:

```bash 
plite vsc --editor vim
```
where vim could be replaced with your favourite editor. This will open a config file with one line, 
showing you the current editor. 

Add the following line

```bash
dispatcher=/path/to/dispatch-basic
```

where /path/to is substituted with the actual path - then save.


Basic Usage
===========
This following is a "hello world" for Pipelite.

```bash
plite new filter-seq
```
 creates a new pipeline directory and a set of skeletonn files.
```bash
plite vp filter-seq
```
 views the pipeline file located in filter-seq/filter-seq.pipeline
```bash
less filter-seq/filter-seq.datasource
```
 take a look at the datasource for the pipeline
```bash
plite run filter-seq
```
  run the single step pipeline over the datasource
```bash
plite symlink -f name filter-seq
```
  symlink recognisable identifiers to the pipeline files

```
ls filter-seq/symlink/seq/1/
```

You can view the raw "command" file using 

```bash
plite vg feature-seq
```

If you don't want to actually dispatch the pipeline then you can
use the -m switch

```bash
plite run -m filter-seq
```

This still produces the raw "command file" that allows you to inspect what will be run


Pipeline and Datasource Specification
=====================================

This a list of thing that currently will not be warned against but which will result 
in strange behaviour (they will be removed from the list as updates are made 
to warn or allow the behaviour):

* No dots in datasource names - underscores and hyphens are ok 
  (i.e. no column name "file.gz", use "file-gz" instead)
* The datasource must be tab delimited
* No blank lines at the beginning of a pipeline file

Dispatchers
===========
The dispatch-basic dispatcher is for demonstration and other dispatchers will be made available
 and does not offer parallelisation over cores, 
just ensuring jobs with dependencies are executed in the right order. This is on the todo list.

We have in use a dispatcher for Platform LSF that will be made available soon - contact 
me if you wish to use this right away. We will look to add dispatchers that utilise other
job management/schedule systems in the future.
