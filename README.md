Pipelite (App-Pipeline-Lite)
=================

Pipelite is still in an experimental phase - Pre Alpha would be the best description.

Installation
============
curl -L https://github.com/njgit/App-Pipeline-Lite/blob/master/bin/packed/plite > ~/bin/plite
curl -L https://github.com/njgit/App-Pipeline-Lite/blob/master/bin/packed/dispatch-basic > ~/bin/dispatch-basic

plite vsc

Enter your favourite editor
set 
 dispatcher=~/bin/dispatch-basic

Basic Usage
===========
This gives the basic way Pipelite works.

The executable is "plite"

Pipeline and Datasource Specification
=====================================

This a list of thing that currently will not be warned against but which will result 
in possible strange behaviour (they will be removed from the list as updates are made 
to warn or allow the behaviour):

* No dots in datasource names - underscores and hyphens are ok 
  (i.e. no column name "file.gz", use "file-gz" instead)
* The datasource must be tab delimited
* No blank lines at the beginning of a pipeline file

Dispatchers
===========
The dispatch-basic dispatcher is for demonstration and does not offer parallelisation over cores, 
just ensuring jobs with dependencies are executed in the right order. This is on the todo list.

We have in use a dispatcher for Platform LSF that will be made available soon - contact 
me if you wish to use this right away. We will look to add dispatchers that utilise other
job management/schedule systems in the future.
