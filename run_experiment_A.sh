#!/bin/bash

# 실험 A: Bloom vs Ribbon 필터 성능 비교 스크립트
# 컴팩션이 자주 발생하도록 설정하여 필터 간 성능 차이를 극대화

# 결과 저장 디렉토리 생성
RESULTS_DIR="filter_benchmark_results"
mkdir -p $RESULTS_DIR

# DB 경로 설정
BLOOM_DB_PATH="bloom_filter_db"
RIBBON_DB_PATH="ribbon_filter_db"

# 사전에 디렉토리 정리
rm -rf $BLOOM_DB_PATH $RIBBON_DB_PATH

# 공통 벤치마크 옵션
# 컴팩션이 자주 발생하도록 설정
COMMON_OPTIONS="
  --num=5000000 \
  --value_size=1024 \
  --key_size=32 \
  --threads=2 \
  --block_size=4096 \
  --write_buffer_size=8388608 \
  --target_file_size_base=8388608 \
  --compression_type=none \
  --statistics
  --report_bg_io_stats=true
"

# 모니터링 함수 - CPU, 메모리, 디스크 I/O 모니터링
monitor_resources() {
  local pid=$1
  local output_file=$2
  local filter_type=$3
  local benchmark_type=$4
  
  echo "타임스탬프,CPU(%),메모리(KB),디스크읽기(KB),디스크쓰기(KB),필터타입,벤치마크" > $output_file
  
  while kill -0 $pid 2>/dev/null; do
    local stats=$(ps -p $pid -o %cpu,%mem,rss | tail -1)
    local cpu=$(echo $stats | awk '{print $1}')
    local mem=$(echo $stats | awk '{print $3}')
    
    # 프로세스의 디스크 I/O 통계 (macOS용)
    local disk_stats=$(iotop -P $pid 2>/dev/null | tail -1 || echo "0 0")
    local disk_read=$(echo $disk_stats | awk '{print $3}')
    local disk_write=$(echo $disk_stats | awk '{print $4}')
    
    # 결과 기록
    echo "$(date +%s),$cpu,$mem,$disk_read,$disk_write,$filter_type,$benchmark_type" >> $output_file
    sleep 1
  done
}

# fillrandom 벤치마크 (Bloom)
run_bloom_fillrandom() {
  echo "===== Bloom 필터 fillrandom 벤치마크 시작 (bits_per_key=10) ====="
  
  local log_file="$RESULTS_DIR/bloom_fillrandom.log"
  local monitor_file="$RESULTS_DIR/bloom_fillrandom_resources.csv"
  
  ./db_bench $COMMON_OPTIONS \
    --benchmarks=fillrandom \
    --bloom_bits=10 \
    --use_ribbon_filter=false \
    --use_existing_db=0 \
    --db=$BLOOM_DB_PATH \
    > $log_file 2>&1 &
  
  local bench_pid=$!
  echo "Bloom fillrandom 벤치마크 PID: $bench_pid"
  
  monitor_resources $bench_pid $monitor_file "Bloom" "fillrandom" &
  local monitor_pid=$!
  
  wait $bench_pid
  kill $monitor_pid 2>/dev/null
  wait $monitor_pid 2>/dev/null
  
  # 컴팩션 통계 추출
  echo "Bloom 필터 컴팩션 통계:" >> $log_file
  grep -E "compaction|Compaction" $log_file >> "$RESULTS_DIR/bloom_compaction_stats.log"
  
  echo "Bloom fillrandom 완료. 결과: $log_file"
  echo "1분 동안 대기 중..."
  sleep 60
}

# fillrandom 벤치마크 (Ribbon)
run_ribbon_fillrandom() {
  echo "===== Ribbon 필터 fillrandom 벤치마크 시작 (bits_per_key=10) ====="
  
  local log_file="$RESULTS_DIR/ribbon_fillrandom.log"
  local monitor_file="$RESULTS_DIR/ribbon_fillrandom_resources.csv"
  
  ./db_bench $COMMON_OPTIONS \
    --benchmarks=fillrandom \
    --bloom_bits=10 \
    --use_ribbon_filter=true \
    --use_existing_db=0 \
    --db=$RIBBON_DB_PATH \
    > $log_file 2>&1 &
  
  local bench_pid=$!
  echo "Ribbon fillrandom 벤치마크 PID: $bench_pid"
  
  monitor_resources $bench_pid $monitor_file "Ribbon" "fillrandom" &
  local monitor_pid=$!
  
  wait $bench_pid
  kill $monitor_pid 2>/dev/null
  wait $monitor_pid 2>/dev/null
  
  # 컴팩션 통계 추출
  echo "Ribbon 필터 컴팩션 통계:" >> $log_file
  grep -E "compaction|Compaction" $log_file >> "$RESULTS_DIR/ribbon_compaction_stats.log"
  
  echo "Ribbon fillrandom 완료. 결과: $log_file"
  echo "1분 동안 대기 중..."
  sleep 60
}

# readrandom 벤치마크 (Bloom)
run_bloom_readrandom() {
  echo "===== Bloom 필터 readrandom 벤치마크 시작 (bits_per_key=10) ====="
  
  local log_file="$RESULTS_DIR/bloom_readrandom.log"
  local monitor_file="$RESULTS_DIR/bloom_readrandom_resources.csv"
  
  ./db_bench $COMMON_OPTIONS \
    --benchmarks=readrandom \
    --bloom_bits=10 \
    --use_ribbon_filter=false \
    --use_existing_db=1 \
    --db=$BLOOM_DB_PATH \
    > $log_file 2>&1 &
  
  local bench_pid=$!
  echo "Bloom readrandom 벤치마크 PID: $bench_pid"
  
  monitor_resources $bench_pid $monitor_file "Bloom" "readrandom" &
  local monitor_pid=$!
  
  wait $bench_pid
  kill $monitor_pid 2>/dev/null
  wait $monitor_pid 2>/dev/null
  
  echo "Bloom readrandom 완료. 결과: $log_file"
  echo "1분 동안 대기 중..."
  sleep 60
}

# readrandom 벤치마크 (Ribbon)
run_ribbon_readrandom() {
  echo "===== Ribbon 필터 readrandom 벤치마크 시작 (bits_per_key=10) ====="
  
  local log_file="$RESULTS_DIR/ribbon_readrandom.log"
  local monitor_file="$RESULTS_DIR/ribbon_readrandom_resources.csv"
  
  ./db_bench $COMMON_OPTIONS \
    --benchmarks=readrandom \
    --bloom_bits=10 \
    --use_ribbon_filter=true \
    --use_existing_db=1 \
    --db=$RIBBON_DB_PATH \
    > $log_file 2>&1 &
  
  local bench_pid=$!
  echo "Ribbon readrandom 벤치마크 PID: $bench_pid"
  
  monitor_resources $bench_pid $monitor_file "Ribbon" "readrandom" &
  local monitor_pid=$!
  
  wait $bench_pid
  kill $monitor_pid 2>/dev/null
  wait $monitor_pid 2>/dev/null
  
  echo "Ribbon readrandom 완료. 결과: $log_file"
  echo "1분 동안 대기 중..."
  sleep 60
}

# readwhilewriting 벤치마크 (Bloom) - 컴팩션이 자주 발생하도록 설정
run_bloom_readwhilewriting() {
  echo "===== Bloom 필터 readwhilewriting 벤치마크 시작 (bits_per_key=10) ====="
  
  local log_file="$RESULTS_DIR/bloom_readwhilewriting.log"
  local monitor_file="$RESULTS_DIR/bloom_readwhilewriting_resources.csv"
  
  ./db_bench $COMMON_OPTIONS \
    --benchmarks=readwhilewriting \
    --bloom_bits=10 \
    --use_ribbon_filter=false \
    --use_existing_db=1 \
    --db=$BLOOM_DB_PATH \
    > $log_file 2>&1 &
  
  local bench_pid=$!
  echo "Bloom readwhilewriting 벤치마크 PID: $bench_pid"
  
  monitor_resources $bench_pid $monitor_file "Bloom" "readwhilewriting" &
  local monitor_pid=$!
  
  wait $bench_pid
  kill $monitor_pid 2>/dev/null
  wait $monitor_pid 2>/dev/null
  
  # 컴팩션 통계 추출
  echo "Bloom 필터 readwhilewriting 컴팩션 통계:" >> $log_file
  grep -E "compaction|Compaction" $log_file >> "$RESULTS_DIR/bloom_readwhilewriting_compaction.log"
  
  echo "Bloom readwhilewriting 완료. 결과: $log_file"
  echo "1분 동안 대기 중..."
  sleep 60
}

# readwhilewriting 벤치마크 (Ribbon) - 컴팩션이 자주 발생하도록 설정
run_ribbon_readwhilewriting() {
  echo "===== Ribbon 필터 readwhilewriting 벤치마크 시작 (bits_per_key=10) ====="
  
  local log_file="$RESULTS_DIR/ribbon_readwhilewriting.log"
  local monitor_file="$RESULTS_DIR/ribbon_readwhilewriting_resources.csv"
  
  ./db_bench $COMMON_OPTIONS \
    --benchmarks=readwhilewriting \
    --bloom_bits=10 \
    --use_ribbon_filter=true \
    --use_existing_db=1 \
    --db=$RIBBON_DB_PATH \
    > $log_file 2>&1 &
  
  local bench_pid=$!
  echo "Ribbon readwhilewriting 벤치마크 PID: $bench_pid"
  
  monitor_resources $bench_pid $monitor_file "Ribbon" "readwhilewriting" &
  local monitor_pid=$!
  
  wait $bench_pid
  kill $monitor_pid 2>/dev/null
  wait $monitor_pid 2>/dev/null
  
  # 컴팩션 통계 추출
  echo "Ribbon 필터 readwhilewriting 컴팩션 통계:" >> $log_file
  grep -E "compaction|Compaction" $log_file >> "$RESULTS_DIR/ribbon_readwhilewriting_compaction.log"
  
  echo "Ribbon readwhilewriting 완료. 결과: $log_file"
  echo "1분 동안 대기 중..."
  sleep 60
}

# 결과 요약 생성
generate_summary() {
  echo "===== 벤치마크 결과 요약 ====="
  
  # 성능 결과 요약
  echo "Bloom 필터 결과:"
  echo "- fillrandom:"
  grep "ops/sec" $RESULTS_DIR/bloom_fillrandom.log
  
  echo "- readrandom:"
  grep "ops/sec" $RESULTS_DIR/bloom_readrandom.log
  
  echo "- readwhilewriting:"
  grep "ops/sec" $RESULTS_DIR/bloom_readwhilewriting.log
  
  echo ""
  
  echo "Ribbon 필터 결과:"
  echo "- fillrandom:"
  grep "ops/sec" $RESULTS_DIR/ribbon_fillrandom.log
  
  echo "- readrandom:"
  grep "ops/sec" $RESULTS_DIR/ribbon_readrandom.log
  
  echo "- readwhilewriting:"
  grep "ops/sec" $RESULTS_DIR/ribbon_readwhilewriting.log
  
  echo ""
  
  # 컴팩션 통계 요약
  echo "컴팩션 통계 요약:"
  echo "- Bloom 컴팩션 횟수:"
  grep -c "compaction" "$RESULTS_DIR/bloom_compaction_stats.log" || echo "0"
  echo "- Ribbon 컴팩션 횟수:"
  grep -c "compaction" "$RESULTS_DIR/ribbon_compaction_stats.log" || echo "0"
  
  echo ""
  echo "readwhilewriting 컴팩션 통계:"
  echo "- Bloom readwhilewriting 컴팩션 횟수:"
  grep -c "compaction" "$RESULTS_DIR/bloom_readwhilewriting_compaction.log" || echo "0"
  echo "- Ribbon readwhilewriting 컴팩션 횟수:"
  grep -c "compaction" "$RESULTS_DIR/ribbon_readwhilewriting_compaction.log" || echo "0"
  
  echo ""
  echo "각 벤치마크별 리소스 사용량 데이터는 $RESULTS_DIR 디렉토리에 저장되었습니다."
}

# 메인 실행 코드
main() {
  echo "실험 A: Bloom vs Ribbon 필터 성능 비교 (bits_per_key=10, 컴팩션 최적화)"
  echo "시작 시간: $(date)"
  echo ""
  
  # 이전 결과 정리
  mkdir -p $RESULTS_DIR
  rm -f $RESULTS_DIR/*.log $RESULTS_DIR/*.csv
  
  # fillrandom 벤치마크
  run_bloom_fillrandom
  run_ribbon_fillrandom
  
  # readrandom 벤치마크
  run_bloom_readrandom
  run_ribbon_readrandom
  
  # readwhilewriting 벤치마크
  run_bloom_readwhilewriting
  run_ribbon_readwhilewriting
  
  # 결과 요약
  generate_summary
  
  echo ""
  echo "실험 완료 시간: $(date)"
  
  # 각 필터 DB 사이즈 비교
  echo "DB 사이즈 비교:"
  echo "- Bloom DB 사이즈: $(du -sh $BLOOM_DB_PATH | cut -f1)"
  echo "- Ribbon DB 사이즈: $(du -sh $RIBBON_DB_PATH | cut -f1)"
}

# 스크립트 실행
main