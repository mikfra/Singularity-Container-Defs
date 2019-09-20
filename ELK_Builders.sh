#!/bin/bash -x

###This script will setup a quick elasticsearch,kibana, & logstash instance

#Check to see if singularity is installed 
#command -v singularity >/dev/null 2>&1 || {echo >&2 "Singularity Not installed"; exit 1; }

declare -a ELK=("elasticsearch" "logstash" "kibana")
declare -a FUNCT=("make_elasticsearch" "make_logstash" "make_kibana")

#Make root RunDir and root directories for singularity containers
read -p "Enter the Directory you would like to install Elasticsearch[Default=  /containers]: " read_dir 
read_dir=${read_dir:-"/hello"}
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
	com="cp -rf $cdir/$i /temp"
	singularity_cp
done
}

make_logstash() {
echo "
#!/bin/bash 

singularity shell \\
	-B ./rundir:/usr/share/logstash \\
	-B /home/mrf/pcaps/csv:/pcaps \\
	./logstash_7.3.2.sif" > $read_dir/$x/run.sh

lcpdir=(config data modules piplines tools x-pack)
cdir=/usr/share/logstash
for i in "${lcpdir[@]}"; do
	com="cp -rf $cdir/$i /temp"
	singularity_cp
done
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
	com="cp -rf $cdir/$i /temp"
	singularity_cp
done
}

#Checking/Creating associated containers direcotry 
echo "[Setting up containers directory and runscripts]"

for x in ${ELK[*]}; do
	mkdir -p $read_dir/$x/rundir
	touch $read_dir/$x/run.sh
	if [ -f "$read_dir/$x/$x.sif" ]; then 
		echo "[Containers are already installed]"
	else
		echo "[Pulling $x from DockerHub]"
		singularity pull $read_dir/$x/$x.sif docker://$x:7.3.2
	fi
	make_$x
done
