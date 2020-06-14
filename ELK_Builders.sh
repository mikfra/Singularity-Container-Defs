#!/bin/bash

#Check to see if singularity is installed
#command -v singularity >/dev/null 2>&1 || {echo >&2 "Singularity Not installed"; exit 1; }
#Needto follow up with this later but need to reqrite script for presentation first

#TEMP SET VM MAX MEMORY
sysctl -w vm.max_map_count=262144

#List of elasticsearch stack
declare -a ELK=("elasticsearch" "logstash" "kibana")

#List of deploy script function
declare -a FUNCT=("make_elasticsearch" "make_logstash" "make_kibana")


#Make root RunDir and root directories for singularity containers. Default is current dir 
read -p "Enter the Directory you would like to install Elasticsearch[Default=  $(pwd)]: " read_dir
read_dir=${read_dir:-"$(pwd)"}
echo "[Directory= $read_dir]"

#Ready user name wanted. default is nobody
read -p "What user will be running the containers. i.e. not root?[Default= nobody]"
user=${user:-"1000"}
echo "[User is $user]"


singularity_cp() {
gdir=$read_dir/$x/rundir
singularity exec \
	-B $gdir:/temp \
	$read_dir/$x/${x}_7.7.1.sif $com

}

#Make the elasticsearch run script
make_elasticsearch() {
echo "
#!/bin/bash
pwd="$read_dir"/elasticsearch
rundir=\$pwd/rundir
contdir=/usr/share/elasticsearch
singularity instance start \\
	-B \$rundir/config:\$contdir/config \\
	-B \$rundir/data:\$contdir/data \\
	-B \$rundir/logs:\$contdir/logs \\
	\$pwd/elasticsearch_7.7.1.sif elasticsearch" > $read_dir/$x/run.sh

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

#Make a basic config file for elasticsearch
config_yml_elasticsearch() {
if [ -f "$read_dir/elasticsearch/rundir/config/elasticsearch.yml" ]; then
	echo [Elasticsearch.yml exists]
	echo "
    cluster.name: "${HOSTNAME}_cluster"
    network.host: 0.0.0.0
    node.master: true
    node.name: "${HOSTNAME}_master"
    discovery.type: single-node
    discovery.zen.minimum_master_nodes: 1
    discovery.zen.ping.unicast.hosts: ["0.0.0.0:9300"]
    path:
        logs: /usr/share/elasticsearch/logs/${HOSTNAME}
        data: /usr/share/elasticsearch/data/${HOSTNAME}" > $read_dir/$x/rundir/config/$x.yml
else
	echo "[No file exist? What You Doin'! Forget about it!]"
fi
}

#Make Logstash run script
make_logstash() {
echo "
#!/bin/bash
pwd="$read_dir"/logstash
rundir=\$pwd/rundir
contdir=/usr/share/kibana
singularity shell \\
	-B \$rundir/config:\$contdir/config \\
	-B \$rundir/modules:\$contdir/modules \\
	-B \$rundir/data:\$contdir/data \\
	-B \$rundir/pipeline:\$contdir/pipeline \\
	-B \$rundir/tools:\$contdir/tools \\
	-B \$rundir/x-pack:\$contdir/x-pack \\
	\$pwd/logstash_7.7.1.sif" > $read_dir/$x/run.sh

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

#Make Logstash config
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

#Make Kidana Runscript
make_kibana() {
echo "
#!/bin/bash
pwd="$read_dir"/kibana
rundir=\$pwd/rundir
contdir=/usr/share/kibana
singularity instance start \\
	-B \$rundir/config:\$contdir/config \\
	-B \$rundir/data:\$contdir/data \\
	-B \$rundir/optimize:\$contdir/optimize \\
	-B \$rundir/node_modules:\$contdir/node_modules \\
	\$pwd/kibana_7.7.1.sif kibana" > $read_dir/$x/run.sh

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

#Make Kibana Config 
config_yml_kibana() {
if [ -f "$read_dir/$x/rundir/config/$x.yml" ]; then
    echo "
    server.name: kibana
    server.host: "${HOSTNAME}"
    elasticsearch.hosts: http://0:9200
    " > $read_dir/$x/rundir/config/$x.yml
else
	echo "[No file exist? What You Doin'! Forget about it!]"
fi
}

#Checking/Creating associated containers direcotry
echo "[Setting up containers directory and runscripts]"

#Run through functions to create the ELK Stack
for x in ${ELK[*]}; do
	mkdir -p $read_dir/$x/rundir
	touch $read_dir/$x/run.sh
	if [ -f "$read_dir/$x/${x}_7.7.1.sif" ]; then
		echo "[Containers are already installed]"
	else
		echo "[Pulling $x from DockerHub]"
		singularity pull $read_dir/$x/${x}_7.7.1.sif docker://$x:7.7.1
	fi
	echo "Making the Directories for $x"
	make_$x
	echo "Making the Config files for $x"
	config_yml_$x
done

chown $user.$user -R $read_dir
