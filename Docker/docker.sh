docker stop demergi-dpi
docker rm demergi-dpi
docker pull docker.io/hectorm/demergi:latest
docker run -d -p 8080:8080 --name demergi-dpi --restart=unless-stopped docker.io/hectorm/demergi:latest
docker image prune -a -f
