pkill -f "docker-compose .*simd.* logs" | true
pkill -f "tail .*.log" | true
