
EXE="ds4-server"

OPTS=" --port 8888 $OPTS "

LOG="$EXE-$(date +%s).log"

./$EXE $OPTS 2>&1 | tee $LOG

