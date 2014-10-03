#!/usr/bin/env bash
startxvfb() {
    XVFB=/usr/bin/Xvfb
    XVFBARGS=":99 -screen 0 1024x768x24 -fbdir /var/run -ac"
    PIDFILE=/var/run/xvfb.pid
    case "$1" in
        start)
            echo "Starting Xvfb"
                start-stop-daemon --start --quiet --pidfile $PIDFILE --make-pidfile --background --exec $XVFB -- $XVFBARGS
            ;;
        stop)
            echo "Stopping Xvfb"
            start-stop-daemon --stop --quiet --pidfile $PIDFILE
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
CHROME_PATH="/full/path/to/chromedriver"
SELENIUM_PATH="/full/pat/to/selenium-server-standalone-X.XX.X.jar"
case "$1" in
    start)
        echo 'Starting test env...'
        startxvfb $1
        java -Dwebdriver.chrome.driver=$CHROME_PATH -jar $SELENIUM_PATH
        ;;
    stop)
        startxvfb $1
        "Stopped xvfb"
        exit 0
        ;;
     *)
        echo "$0 {start|stop}"
        exit 1;
        ;;
esac
