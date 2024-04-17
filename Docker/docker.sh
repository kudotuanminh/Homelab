docker stop endlessh
docker rm endlessh
docker pull shizunge/endlessh-go:latest
docker run -d -p 2112:2112 -p 2222:2222 --name endlessh --restart=unless-stopped shizunge/endlessh-go:latest -interval_ms 10000 -geoip_supplier ip-api -enable_prometheus -logtostderr -v=1
docker stop demergi-dpi
docker rm demergi-dpi
docker pull docker.io/hectorm/demergi:latest
docker run -d -p 8080:8080 --name demergi-dpi --restart=uneless-stopped docker.io/hectorm/demergi:latest
docker stop portainer-agent
docker rm portainer-agent
docker pull portainer/agent:latest
docker run -d  -p 9001:9001 -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker/volumes:/var/lib/docker/volumes --name portainer-agent --restart=always portainer/agent:latest
docker image prune -a -f
