
# put model into VRAM
export DS4_CUDA_COPY_MODEL=1


normal(){
#export DS4_CUDA_Q8_F16_CACHE_MB=2048
export DS4_CUDA_Q8_F16_CACHE_MB=3072
#export DS4_CUDA_Q8_F16_CACHE_MB=4096 # OOM on H20 96GB
}
normal

mtp(){
OPTS=" --mtp DeepSeek-V4-Flash-MTP-Q4K-Q8_0-F32.gguf $OPTS "
}
mtp

EXE="ds4-server"

#OPTS=" --threads 4 $OPTS "
OPTS=" --threads 30 $OPTS "
OPTS=" --port 8888 --prefill-chunk 8192 $OPTS "

LOG="$EXE-$(date +%s).log"

set -x

./$EXE $OPTS 2>&1 | tee $LOG

