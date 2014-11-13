#!/usr/bin/env bash
startxvfb() {
    XVFB=$(which Xvfb)
    XVFBARGS=":99 -screen 0 1024x768x24 -fbdir /var/run -ac"
    PIDFILE=/var/run/xvfb.pid
    case "$1" in
        start)
            echo "Starting Xvfb"
            sudo start-stop-daemon --start --quiet --pidfile $PIDFILE --make-pidfile --background --exec $XVFB -- $XVFBARGS
            ;;
        stop)
            echo "Stopping Xvfb"
            sudo start-stop-daemon --stop --quiet --pidfile $PIDFILE
            if [ -e $PIDFILE ]
                then sudo rm -f $PIDFILE
            fi
            ;;
        *)
            echo "ERROR"
            exit 1
    esac
}

startselenium() {
    PIDFILE=/var/run/selenium.pid
    JAVA=$(which java)
    JAVA_ARGS="-Dwebdriver.chrome.driver=$CHROME_PATH -jar $SELENIUM_PATH"
    case "$1" in
        start)
            echo "Starting selenium"
            sudo start-stop-daemon --start --quiet --pidfile $PIDFILE --make-pidfile --background --exec $JAVA -- $JAVA_ARGS
            ;;
        stop)
            echo "Stopping selenium"
            sudo start-stop-daemon --stop --quiet --pidfile $PIDFILE
            if [ -e $PIDFILE ]
                then sudo rm -f $PIDFILE
            fi
            ;;
        *)
            echo "ERROR"
            exit 1
    esac
}

if [[ $# -eq 0 ]]; then
    echo 'No arguments...'
    exit 1;
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CHROME_PATH="$DIR/chromedriver"
SELENIUM_PATH="$DIR/selenium-server-standalone.jar"
case "$1" in
    start)
        echo -n 'Root privileges will be required...'
        sudo echo 'Starting test env...'
        #startxvfb $1
        startselenium $1
        ;;
    stop)
        echo -n 'Root privileges will be required...'
        sudo echo 'Stopping test env...'
        #startxvfb $1
        startselenium $1
        exit 0
        ;;
     *)
        echo "$0 {start|stop}"
        exit 1;
        ;;
esac
