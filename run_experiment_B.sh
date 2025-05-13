#!/bin/bash

# 실험 B: 다양한 bits_per_key 값에 따른 Bloom vs Ribbon 필터 성능 비교 스크립트
# bits_per_key 값을 0, 5, 10, 15, 20, 25로 변경하며 실험

# 메인 결과 디렉토리 생성
MAIN_RESULTS_DIR="filter_benchmark_results_varying_bits"
mkdir -p $MAIN_RESULTS_DIR

# bits_per_key 값 배열 정의
BITS_PER_KEY_VALUES=(0 5 10 15 20 25)

# 각 bits_per_key 값에 대해 실험 실행
for BITS_PER_KEY in "${BITS_PER_KEY_VALUES[@]}"; do
  echo "======================================================"
  echo "bits_per_key = $BITS_PER_KEY 실험 시작"
  echo "======================================================"
  
  # 현재 bits_per_key 값에 대한 결과 디렉토리 설정
  RESULTS_DIR="${MAIN_RESULTS_DIR}/bits_${BITS_PER_KEY}"
  mkdir -p $RESULTS_DIR
  
  # DB 경로 설정
  BLOOM_DB_PATH="bloom_filter_db_bits_${BITS_PER_KEY}"
  RIBBON_DB_PATH="ribbon_filter_db_bits_${BITS_PER_KEY}"
  
  # 사전에 디렉토리 정리
  rm -rf $BLOOM_DB_PATH $RIBBON_DB_PATH
  
  # 공통 벤치마크 옵션
  # 컴팩션이 자주 발생하도록 설정
  COMMON_OPTIONS="
    --num=3000000 \
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
  
  # fillrandom 벤치마크 (Bloom)
  run_bloom_fillrandom() {
    echo "===== Bloom 필터 fillrandom 벤치마크 시작 (bits_per_key=$BITS_PER_KEY) ====="
    
    local log_file="$RESULTS_DIR/bloom_fillrandom.log"
    
    ./db_bench $COMMON_OPTIONS \
      --benchmarks=fillrandom \
      --bloom_bits=$BITS_PER_KEY \
      --use_ribbon_filter=false \
      --use_existing_db=0 \
      --db=$BLOOM_DB_PATH \
      > $log_file 2>&1
    
    # 컴팩션 통계 추출
    echo "Bloom 필터 컴팩션 통계:" >> $log_file
    grep -E "compaction|Compaction" $log_file >> "$RESULTS_DIR/bloom_compaction_stats.log"
    
    echo "Bloom fillrandom 완료. 결과: $log_file"
    echo "3분 동안 대기 중..."
    sleep 180
  }
  
  # fillrandom 벤치마크 (Ribbon)
  run_ribbon_fillrandom() {
    echo "===== Ribbon 필터 fillrandom 벤치마크 시작 (bits_per_key=$BITS_PER_KEY) ====="
    
    local log_file="$RESULTS_DIR/ribbon_fillrandom.log"
    
    ./db_bench $COMMON_OPTIONS \
      --benchmarks=fillrandom \
      --bloom_bits=$BITS_PER_KEY \
      --use_ribbon_filter=true \
      --use_existing_db=0 \
      --db=$RIBBON_DB_PATH \
      > $log_file 2>&1
    
    # 컴팩션 통계 추출
    echo "Ribbon 필터 컴팩션 통계:" >> $log_file
    grep -E "compaction|Compaction" $log_file >> "$RESULTS_DIR/ribbon_compaction_stats.log"
    
    echo "Ribbon fillrandom 완료. 결과: $log_file"
    echo "3분 동안 대기 중..."
    sleep 180
  }
  
  # readrandom 벤치마크 (Bloom)
  run_bloom_readrandom() {
    echo "===== Bloom 필터 readrandom 벤치마크 시작 (bits_per_key=$BITS_PER_KEY) ====="
    
    local log_file="$RESULTS_DIR/bloom_readrandom.log"
    
    ./db_bench $COMMON_OPTIONS \
      --benchmarks=readrandom \
      --bloom_bits=$BITS_PER_KEY \
      --use_ribbon_filter=false \
      --use_existing_db=1 \
      --db=$BLOOM_DB_PATH \
      > $log_file 2>&1
    
    echo "Bloom readrandom 완료. 결과: $log_file"
    echo "3분 동안 대기 중..."
    sleep 180
  }
  
  # readrandom 벤치마크 (Ribbon)
  run_ribbon_readrandom() {
    echo "===== Ribbon 필터 readrandom 벤치마크 시작 (bits_per_key=$BITS_PER_KEY) ====="
    
    local log_file="$RESULTS_DIR/ribbon_readrandom.log"
    
    ./db_bench $COMMON_OPTIONS \
      --benchmarks=readrandom \
      --bloom_bits=$BITS_PER_KEY \
      --use_ribbon_filter=true \
      --use_existing_db=1 \
      --db=$RIBBON_DB_PATH \
      > $log_file 2>&1
    
    echo "Ribbon readrandom 완료. 결과: $log_file"
    echo "3분 동안 대기 중..."
    sleep 180
  }
  
  # readwhilewriting 벤치마크 (Bloom)
  run_bloom_readwhilewriting() {
    echo "===== Bloom 필터 readwhilewriting 벤치마크 시작 (bits_per_key=$BITS_PER_KEY) ====="
    
    local log_file="$RESULTS_DIR/bloom_readwhilewriting.log"
    
    ./db_bench $COMMON_OPTIONS \
      --benchmarks=readwhilewriting \
      --bloom_bits=$BITS_PER_KEY \
      --use_ribbon_filter=false \
      --use_existing_db=1 \
      --db=$BLOOM_DB_PATH \
      > $log_file 2>&1
    
    # 컴팩션 통계 추출
    echo "Bloom 필터 readwhilewriting 컴팩션 통계:" >> $log_file
    grep -E "compaction|Compaction" $log_file >> "$RESULTS_DIR/bloom_readwhilewriting_compaction.log"
    
    echo "Bloom readwhilewriting 완료. 결과: $log_file"
    echo "3분 동안 대기 중..."
    sleep 180
  }
  
  # readwhilewriting 벤치마크 (Ribbon)
  run_ribbon_readwhilewriting() {
    echo "===== Ribbon 필터 readwhilewriting 벤치마크 시작 (bits_per_key=$BITS_PER_KEY) ====="
    
    local log_file="$RESULTS_DIR/ribbon_readwhilewriting.log"
    
    ./db_bench $COMMON_OPTIONS \
      --benchmarks=readwhilewriting \
      --bloom_bits=$BITS_PER_KEY \
      --use_ribbon_filter=true \
      --use_existing_db=1 \
      --db=$RIBBON_DB_PATH \
      > $log_file 2>&1
    
    # 컴팩션 통계 추출
    echo "Ribbon 필터 readwhilewriting 컴팩션 통계:" >> $log_file
    grep -E "compaction|Compaction" $log_file >> "$RESULTS_DIR/ribbon_readwhilewriting_compaction.log"
    
    echo "Ribbon readwhilewriting 완료. 결과: $log_file"
    echo "3분 동안 대기 중..."
    sleep 180
  }
  
  # 결과 요약 생성
  generate_summary() {
    echo "===== bits_per_key=$BITS_PER_KEY 벤치마크 결과 요약 ====="
    local summary_file="$RESULTS_DIR/summary.log"
    
    # 성능 결과 요약
    echo "Bloom 필터 결과 (bits_per_key=$BITS_PER_KEY):" | tee -a $summary_file
    echo "- fillrandom:" | tee -a $summary_file
    grep "ops/sec" $RESULTS_DIR/bloom_fillrandom.log | tee -a $summary_file
    
    echo "- readrandom:" | tee -a $summary_file
    grep "ops/sec" $RESULTS_DIR/bloom_readrandom.log | tee -a $summary_file
    
    echo "- readwhilewriting:" | tee -a $summary_file
    grep "ops/sec" $RESULTS_DIR/bloom_readwhilewriting.log | tee -a $summary_file
    
    echo "" | tee -a $summary_file
    
    echo "Ribbon 필터 결과 (bits_per_key=$BITS_PER_KEY):" | tee -a $summary_file
    echo "- fillrandom:" | tee -a $summary_file
    grep "ops/sec" $RESULTS_DIR/ribbon_fillrandom.log | tee -a $summary_file
    
    echo "- readrandom:" | tee -a $summary_file
    grep "ops/sec" $RESULTS_DIR/ribbon_readrandom.log | tee -a $summary_file
    
    echo "- readwhilewriting:" | tee -a $summary_file
    grep "ops/sec" $RESULTS_DIR/ribbon_readwhilewriting.log | tee -a $summary_file
    
    echo "" | tee -a $summary_file
    
    # 컴팩션 통계 요약
    echo "컴팩션 통계 요약 (bits_per_key=$BITS_PER_KEY):" | tee -a $summary_file
    echo "- Bloom 컴팩션 횟수:" | tee -a $summary_file
    grep -c "compaction" "$RESULTS_DIR/bloom_compaction_stats.log" | tee -a $summary_file
    echo "- Ribbon 컴팩션 횟수:" | tee -a $summary_file
    grep -c "compaction" "$RESULTS_DIR/ribbon_compaction_stats.log" | tee -a $summary_file
    
    echo "" | tee -a $summary_file
    echo "readwhilewriting 컴팩션 통계:" | tee -a $summary_file
    echo "- Bloom readwhilewriting 컴팩션 횟수:" | tee -a $summary_file
    grep -c "compaction" "$RESULTS_DIR/bloom_readwhilewriting_compaction.log" | tee -a $summary_file
    echo "- Ribbon readwhilewriting 컴팩션 횟수:" | tee -a $summary_file
    grep -c "compaction" "$RESULTS_DIR/ribbon_readwhilewriting_compaction.log" | tee -a $summary_file
    
    echo "" | tee -a $summary_file
    echo "DB 사이즈 비교 (bits_per_key=$BITS_PER_KEY):" | tee -a $summary_file
    echo "- Bloom DB 사이즈: $(du -sh $BLOOM_DB_PATH | cut -f1)" | tee -a $summary_file
    echo "- Ribbon DB 사이즈: $(du -sh $RIBBON_DB_PATH | cut -f1)" | tee -a $summary_file
    
    echo "" | tee -a $summary_file
    echo "각 벤치마크별 결과는 $RESULTS_DIR 디렉토리에 저장되었습니다." | tee -a $summary_file
  }
  
  # 현재 bits_per_key에 대한 실행 코드
  run_experiments() {
    echo "실험 B: Bloom vs Ribbon 필터 성능 비교 (bits_per_key=$BITS_PER_KEY, 컴팩션 최적화)"
    echo "시작 시간: $(date)"
    echo ""
    
    # fillrandom 벤치마크
    run_bloom_fillrandom
    run_ribbon_fillrandom
    
    # readrandom 벤치마크
    run_bloom_readrandom
    run_ribbon_readrandom
    
    # readwhilewriting 벤치마크
    # run_bloom_readwhilewriting
    # run_ribbon_readwhilewriting
    
    # 결과 요약
    generate_summary
    
    echo ""
    echo "bits_per_key=$BITS_PER_KEY 실험 완료 시간: $(date)"
    echo ""
  }
  
  # 현재 bits_per_key에 대한 실험 실행
  run_experiments
done

# 모든 실험 결과 종합 요약
generate_final_summary() {
  echo "======================================================"
  echo "모든 bits_per_key 값에 대한 종합 요약"
  echo "======================================================"
  
  local final_summary="$MAIN_RESULTS_DIR/final_summary.csv"
  
  # CSV 헤더 생성
  echo "bits_per_key,벤치마크,필터타입,ops/초,압축률,DB크기(MB)" > $final_summary
  
  # 각 bits_per_key 값에 대한 결과 추출
  for BITS_PER_KEY in "${BITS_PER_KEY_VALUES[@]}"; do
    RESULTS_DIR="${MAIN_RESULTS_DIR}/bits_${BITS_PER_KEY}"
    
    # Bloom 필터 결과
    local bloom_fillrandom=$(grep "ops/sec" "$RESULTS_DIR/bloom_fillrandom.log" | awk '{print $5}')
    local bloom_readrandom=$(grep "ops/sec" "$RESULTS_DIR/bloom_readrandom.log" | awk '{print $5}')
    local bloom_readwhilewriting=$(grep "ops/sec" "$RESULTS_DIR/bloom_readwhilewriting.log" | awk '{print $5}')
    
    # Ribbon 필터 결과
    local ribbon_fillrandom=$(grep "ops/sec" "$RESULTS_DIR/ribbon_fillrandom.log" | awk '{print $5}')
    local ribbon_readrandom=$(grep "ops/sec" "$RESULTS_DIR/ribbon_readrandom.log" | awk '{print $5}')
    local ribbon_readwhilewriting=$(grep "ops/sec" "$RESULTS_DIR/ribbon_readwhilewriting.log" | awk '{print $5}')
    
    # DB 크기 (MB 단위로 변환)
    local bloom_db_size=$(du -k "bloom_filter_db_bits_${BITS_PER_KEY}" | awk '{print $1/1024}')
    local ribbon_db_size=$(du -k "ribbon_filter_db_bits_${BITS_PER_KEY}" | awk '{print $1/1024}')
    
    # CSV에 결과 추가
    echo "$BITS_PER_KEY,fillrandom,Bloom,$bloom_fillrandom,N/A,$bloom_db_size" >> $final_summary
    echo "$BITS_PER_KEY,readrandom,Bloom,$bloom_readrandom,N/A,$bloom_db_size" >> $final_summary
    echo "$BITS_PER_KEY,readwhilewriting,Bloom,$bloom_readwhilewriting,N/A,$bloom_db_size" >> $final_summary
    echo "$BITS_PER_KEY,fillrandom,Ribbon,$ribbon_fillrandom,N/A,$ribbon_db_size" >> $final_summary
    echo "$BITS_PER_KEY,readrandom,Ribbon,$ribbon_readrandom,N/A,$ribbon_db_size" >> $final_summary
    echo "$BITS_PER_KEY,readwhilewriting,Ribbon,$ribbon_readwhilewriting,N/A,$ribbon_db_size" >> $final_summary
  done
  
  echo "종합 결과가 $final_summary 파일에 저장되었습니다."
  echo "이 CSV 파일을 스프레드시트 프로그램에서 열어 그래프를 생성할 수 있습니다."
}

# 최종 요약 생성
generate_final_summary

echo "======================================================"
echo "모든 bits_per_key 실험이 완료되었습니다."
echo "실험 완료 시간: $(date)"
echo "결과는 $MAIN_RESULTS_DIR 디렉토리에 저장되었습니다."
echo "======================================================"

# 실행 권한 부여
chmod +x run_experiment_B.sh
