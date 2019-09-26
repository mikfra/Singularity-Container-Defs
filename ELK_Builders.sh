#!/bin/bash

#Check to see if singularity is installed
#command -v singularity >/dev/null 2>&1 || {echo >&2 "Singularity Not installed"; exit 1; }

declare -a ELK=("elasticsearch" "logstash" "kibana")
declare -a FUNCT=("make_elasticsearch" "make_logstash" "make_kibana")


#Make root RunDir and root directories for singularity containers
read -p "Enter the Directory you would like to install Elasticsearch[Default=  /containers]: " read_dir
read_dir=${read_dir:-"/scratch/x_scratch/stack"}
echo "[Directory= $read_dir]"
read -p "What user will be running the containers. i.e. not root?[Default= nobody]"
user=${user:-"user"}
echo "[User is $user]"


singularity_cp() {
gdir=$read_dir/$x/rundir
singularity exec \
	-B $gdir:/temp \
	$read_dir/$x/$x.sif $com

}
make_elasticsearch() {
echo "
#!/bin/bash
pwd=$(pwd)
rundir=$pwd/rundir
contdir=/usr/share/elasticsearch
singularity instance start \\
	-B $rundir/config:$contdir/config \\
	-B $rundir/data:$contdir/data \\
	-B $rundir/logs:$contdir/logs \\
	$pwd/es_7.2.0.sif elastic" > $read_dir/$x/run.sh

ecpdir=(config data logs)
cdir=/usr/share/elasticsearch
for i in "${ecpdir[@]}"; do
	if [ -d "$read_dir/$x/rundir/$i" ]; then
		echo "[$i Directory Already Exist]"
	else
		com="cp -rf $cdir/$i /temp"
		singularity_cp
	fi
done
}

config_yml_elasticsearch() {
if [ -f "$read_dir/elasticsearch/rundir/config/elasticsearch.yml" ]; then
	echo [Elasticsearch.yml exists]
	echo "
	cluster.name: "${HOSTNAME}_cluster"
	network.host: 0.0.0.0
	node.master: true
	node.name: "${HOSTNAME}_master"
	cluster.initial_master_nodes:
	    - 0.0.0.0
	discovery.zen.minimum_master_nodes: 1
	discovery.zen.ping.unicast.hosts: ["0.0.0.0:9300"]
	path:
	    logs: /usr/share/elasticsearch/logs/${HOSTNAME}
	    data: /usr/share/elasticsearch/data/${HOSTNAME}" > $read_dir/$x/rundir/config/$x.yml
else
	echo "[No file exist? What You Doin'! Forget about it!]"
fi
}

make_logstash() {
echo "
#!/bin/bash
pwd=$(pwd)
rundir=$pwd/rundir
contdir=/usr/share/kibana
singularity shell \\
	-B $rundir/config:$contdir/config \\
	-B $rundir/modules:$contdir/modules \\
	-B $rundir/data:$contdir/data \\
	-B $rundir/pipeline:$contdir/pipeline \\
	-B $rundir/tools:$contdir/tools \\
	-B $rundir/x-pack:$contdir/x-pack \\
	./logstash_7.3.2.sif" > $read_dir/$x/run.sh

lcpdir=(config data modules pipeline tools x-pack)
cdir=/usr/share/logstash
for i in "${lcpdir[@]}"; do
	if [ -d "$read_dir/$x/rundir/$i" ]; then
		echo "[$i Directory Already Exist]"
	else
		com="cp -rf $cdir/$i /temp"
		singularity_cp
	fi
done
}

config_yml_logstash() {
if [ -f "$read_dir/$x/rundir/config/$x.yml" ]; then
    echo "
		http.host: "0.0.0.0"
    xpack.monitoring.elasticsearch.hosts: [ "http://elasticsearch:9200" ]
    " > $read_dir/$x/rundir/config/$x.yml
else
	echo "[No file exist? What You Doin'! Forget about it!]"
fi
}

make_kibana() {
echo "
#!/bin/bash
pwd=$(pwd)
rundir=$pwd/rundir
contdir=/usr/share/kibana
singularity instance start \\
	-B $rundir/config:$contdir/config \\
	-B $rundir/data:$contdir/data \\
	-B $rundir/optimize:$contdir/optimize \\
	-B $rundir/node_modules:$contdir/node_modules \\
	$pwd/kib_7.2.0.sif kibana" > $read_dir/$x/run.sh

kcpdir=(config data node_modules optimize)
cdir=/usr/share/kibana
for i in "${kcpdir[@]}"; do
	if [ -d "$read_dir/$x/rundir/$i" ]; then
		echo "[$i Directory Already Exist]"
	else
		com="cp -rf $cdir/$i /temp"
		singularity_cp
	fi
done
}

config_yml_kibana() {
if [ -f "$read_dir/$x/rundir/config/$x.yml" ]; then
    echo "
		server.name: kibana
		server.host: "0"
		elasticsearch.hosts: [ "http://0:9200" ]
    " > $read_dir/$x/rundir/config/$x.yml
else
	echo "[No file exist? What You Doin'! Forget about it!]"
fi
}

#Checking/Creating associated containers direcotry
echo "[Setting up containers directory and runscripts]"

for x in ${ELK[*]}; do
	mkdir -p $read_dir/$x/rundir
	touch $read_dir/$x/run.sh
	if [ -f "$read_dir/$x/${x}_7.3.2.sif" ]; then
		echo "[Containers are already installed]"
	else
		echo "[Pulling $x from DockerHub]"
		singularity pull $read_dir/$x/${x}_7.3.2.sif docker://$x:7.3.2
	fi
	make_$x
	config_yml_$x
done
