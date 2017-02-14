## Jenkins Build script for monorepo

These are some scripts/instructions allowing you to trigger specific jenkins jobs in case certain parts of a monorepo changed. You can configure jenkins to trigger builds on a repo if anything changed. However, ops repos often contain things like ansible roles, or terraform files. You don't want to rebuild your entire architecture if all you changed is a single ansible role.


### Config on Jenkins

* All jobs related to the monorepo should be configured so they can be triggered using the same webhook
* Track the build.sh script inside the monorepo
* create a whitelist.yml file in the monorepo root following the specs listed below
* create a main build to trigger automatically, and check out the code in a subdirectory
* That main build should have the init.sh script as main build step
* Make sure there is a valid user, too (check variables in init.sh script)

#### whitelist.yml format

The format is quite simple, it's yaml layed out as follows:

```yaml
job-name:
  - path/to/check
  - another/path
  - path/to/single/file.c

another-job:
  - path/to/other
```

The blank line between the jobs is mandatory. For ansible roles, it's common to have common roles. Rather than typing the same paths everywhere, it's possible to add a _"meta"_ job, prefixed with `__`:

```yaml
__common_ansible_roles:
  - path/to/ansible/common
  - another/path/in/common
```

Comments are allowed on separate lines; Don't put them at the end of a line.

## In the end:

What you should end up with is a build that triggers when you want jenkins to run. That build, though, will not really run anything. It'll check the repo for changes in configured paths. If a change is detected, a webhook will be used to dispatch the actual build on the same branch. As cause, a message will be sent referencing the build number of the main build, and the ID of the user who triggered that build.

## FAQ

_I've set everything up, tweaked the scripts, but when I trigger the build, nothing happens?_

The build script stores git hashes of the paths in a file, that's what it compares. If the hash files don't exist, they're created. As there was no previous hash file to determine whether or not filechanges occured, the script assumes a build should *not* be triggered. It's a fairly easy thing to change, but on balance, it's probably easier to simply add a comment/blank line, and push a new commit. The second time around, a build should be triggered.

