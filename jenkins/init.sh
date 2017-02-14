#!/usr/bin/env bash

#!/usr/bin/env bash

subdir_name="repo"
path_to_build="bin/build.sh"
WEBHOOK_TOKEN="token"
JOBSLINGER_USER="user"
JOBSLINGER_PASS="pass"

## Copy script to working_dir
cd "${WORKSPACE}"
[ ! -e "${subdir_name}/${path_to_build}" ] && echo "Build script not found, failing" && exit 1

exit_code=0

## Copy script from repo into workspace
cp "${subdir_name}/${path_to_build}" ./build.sh
## Make executable - probably not needed, because we're sourcing it
chmod +x build.sh

# source the build script, so the env variables are the same
. build.sh
exit_code=$?
rm build.sh
exit "$exit_code"

