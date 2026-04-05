# Just Scripts

## Major Change 

In the first iteration, we supported Elixir Scripts AND Escripts.

Going forward, let's drop support for Escripts.  Reason:
- There is already support for Escripts (mix escript.build, mix escript.install, etc.)
- With tighter focus: easier to understand, easier to test, easier to maintain

Drop all support for Escripts 
- code
- tests 
- documentation 

## Valid Scripts 

Test for valid scripts:
- a single file, ending in .exs, containing a call to Mix.install 
- a single executable file with no extension, containing an elixir shebang line and a call to Mix.install

Invalid scripts: 
- files ending in .md, ex
- files ending in .exs but no call to Mix.install 
- files with no extension, but not executable 

## Script References 

Update script reference specification:
- we will no longer pull scripts from hex.pm 
- they can only come from a URL, a github repo, or the filesystem
- references always point to a specific file 

Pattern matching: 
- it should be possible to pattern match for a script file within a repo:
    * github:andyl/tango:**/myscript     | recursive search for 'myscript'
    * github:andyl/tango:**/myscript.exs | recursive search for 'myscript.exs'
    * github:andyl/tango:lib/**/myscript | recursive search only under the lib directory

## Find Option 

Currently we have the --cache option. 

I'd also like another option: --find.  It serves to find all scripts within a remote repo.

## Cache Datastore 

In the elr cache directory, I think it would be good to store a datafile to keep basic stats on the scripts in use.

This would probably be a yaml file, with one record for each script.  Each record would have the following fields:
- script name 
- script source  
- script dependenciees (list of deps) 
- install date 
- last execution 
- # uses 

## Indeterminate Options

When I type `elr myscript --help`, it shows the help options for elr, not for myscript.

Currently the usage spec is `elr <script_reference> [<script_args>]`.

Perhaps it should be `elr [elr_args] -- <script_reference> [<script_args>]`.

Is there a better way to segregate between elr args and script args?

## Design Dialog 

As you consider this design change, please push on assumptions, identify flaws
and design questions that should be more carefully considered.

