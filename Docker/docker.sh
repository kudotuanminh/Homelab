docker stop endlessh
docker rm endlessh
docker pull shizunge/endlessh-go:latest
docker run -d -p 2112:2112 -p 2222:2222 --name endlessh --restart=unless-stopped shizunge/endlessh-go:latest -interval_ms 10000 -geoip_supplier ip-api -enable_prometheus -logtostderr -v=1
docker stop demergi-dpi
docker rm demergi-dpi
docker pull docker.io/hectorm/demergi:latest
docker run -d -p 8080:8080 --name demergi-dpi --restart=unless-stopped docker.io/hectorm/demergi:latest
docker image prune -a -f
