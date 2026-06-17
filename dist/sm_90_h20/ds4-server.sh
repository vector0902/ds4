
# put model into VRAM
export DS4_CUDA_COPY_MODEL=1

#export DS4_CUDA_Q8_F16_CACHE_MB=2048
export DS4_CUDA_Q8_F16_CACHE_MB=3072
#export DS4_CUDA_Q8_F16_CACHE_MB=4096 # OOM on H20 96GB

EXE="ds4-server"

OPTS=" --port 8888 --prefill-chunk 8192 --threads 4 $OPTS "

LOG="$EXE-$(date +%s).log"

./$EXE $OPTS 2>&1 | tee $LOG

