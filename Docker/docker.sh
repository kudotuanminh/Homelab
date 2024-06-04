docker pull docker.io/hectorm/demergi:latest
docker stop demergi-dpi
docker rm demergi-dpi
docker run -d -p 8080:8080 -e DEMERGI_WORKERS=4 -e DEMERGI_DOH_URL='https://adguard.local.minhnt.net/dns-query' --name demergi-dpi --restart=unless-stopped docker.io/hectorm/demergi:latest
docker image prune -a -f
