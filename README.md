gp-scripts
==========

Some general-purpose scripts.

In this repo, I'll be keeping some scripts that, from time to time, come in handy...

### resolve.php

This script is particularly useful when working on .git repo where a rebase conflict leaves you feeling like stabbing yourself to death with a broken pencil. This script automatically resolves + addes conflicts in .xml and .php files. Probably other files, too, but haven't checked.
CLI-tool only, works with hhvm:

```bash
$ hhvm resolve.php -m=safe -p=old
```

Will get all conflicted files from git, resolve the conflicts and add them if they pass the `php -l <script>` test (no syntax errors)
