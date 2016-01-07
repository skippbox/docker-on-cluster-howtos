
#####################################################################################################
## PROMETHEUS
#####################################################################################################

Run via compose, or manually:

#cadvisor
docker run \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:rw \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --publish=3002:8080 \
  --detach=true \
  --name=cadvisor \
  google/cadvisor:latest

# Alertmanager
docker run -d -p 9093:9093 \
  -v $PWD/alertmanager.conf:/alertmanager.conf \
  prom/alertmanager \
  -config.file=/alertmanager.conf
  
#Prometheus
docker run -d -p 9090:9090 \
              -v $PWD/prometheus.yml:/etc/prometheus/prometheus.yml \
              -v $PWD/alert.rules:/etc/prometheus/alert.rules \
			  --name=prometheus \
              prom/prometheus \
              -config.file=/etc/prometheus/prometheus.yml \
              -alertmanager.url=http://192.168.33.10:9093
  
Open dev.local:9090
container_memory_usage_bytes{instance="192.168.33.10:3002",job="panamax",name="prometheus"}


# Dashbard

docker run -p 3306:3306 --name mysql      \
   -e MYSQL_DATABASE=dash               \
   -e MYSQL_USER=dbadmin          \
   -e MYSQL_PASSWORD=pw          \
   -e MYSQL_ROOT_PASSWORD=pw	\
   -d mysql

# Initialize Database
docker run --rm -it --link prometheus_mysql_1:db -e DATABASE_URL=mysql2://dbadmin:pw@db:3306/dash prom/promdash ./bin/rake db:migrate
   
# Run Dashboard
docker run -d --link mysql:db -p 3000:3000 --name prometheus-dash -e DATABASE_URL=mysql2://dbadmin:pw@db:3306/dash prom/promdash

Add new server source http://192.168.33.10:9090
add expression cpu...