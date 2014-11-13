#!/usr/bin/env bash
if [ -z "$ARCH" ]; then
    case "$( uname -m )" in
        i?86) ARCH=i486 ;;
        arm*) ARCH=arm ;;
           *) ARCH=$( uname -m ) ;;
    esac
fi
case "${ARCH: -2:2}" in
    64) FILE_NAME=chromedriver_linux64.zip ;;
     *) FILE_NAME=chromedriver_linux32.zip ;;
esac
BASE_URL=http://chromedriver.storage.googleapis.com
VERSION_DIR=$(wget "$BASE_URL/LATEST_RELEASE" -q -O -)

echo "Will download version $VERSION_DIR for architecture $ARCH"
echo "                      filename $FILE_NAME"

wget "$BASE_URL/$VERSION_DIR/$FILE_NAME" -O driver.zip

echo "Unzipping driver"
unzip driver.zip

echo "Cleaning up"
rm -f driver.zip

echo "Getting selenium..."

SEL_VERSION="2.44"
SEL_FILE="selenium-server-standalone-${SEL_VERSION}.0.jar"
wget "http://selenium-release.storage.googleapis.com/$SEL_VERSION/$SEL_FILE" -O selenium-server-standalone.jar
