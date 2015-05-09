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

Download the Pipelite executable - plite, and an associated dispatcher - dispatch-basic::

     wget -O plite https://github.com/njgit/App-Pipeline-Lite/blob/master/bin/packed/plite?raw=true
     wget -O dispatch-basic https://github.com/njgit/App-Pipeline-Lite/blob/master/bin/packed/dispatch-basic?raw=true

Add plite to your PATH in someway - e.g. move plite to a bin directory such as ~/bin

To configure the system run::

    plite vsc --editor vim

Where "vim" can be replaced by your favourite editor. This will open a config file with one line - a configuration variable for the current editor.
Add the following line to set the dispatcher::

    dispatcher=/path/to/dispatch-basic

Where /path/to is substituted with the real path to dispatch-basic.


Quick Start
===========


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
