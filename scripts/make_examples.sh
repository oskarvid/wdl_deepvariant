time seq 0 $((N_SHARDS-1)) |   parallel --eta --halt 2 --joblog "${LOGDIR}/log" --res "${LOGDIR}"   python bin/make_examples.zip     --mode calling     --ref "${REF}"     --reads "${BAM}"     --examples "${OUTPUT_DIR}/examples.tfrecord@${N_SHARDS}.gz"     --regions '"chr20:10,000,000-10,010,000"'     --task {}

