
EXE="ds4-server"
LOG="$EXE-$(date +%s).log"
./$EXE 2>&1 | tee $LOG

