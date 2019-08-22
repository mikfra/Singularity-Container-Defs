# Singularity-Container-Defs
Colletion of container definitions for singularity containers.

# How to use 
1) Download/Install Singularity from the Singularity Github page
2) Pull/CopyPasta a definition file from the Repo
3) sudo singularity build $NAME_OF_CONTAINER $DEFINITION_FILE
    Ex: singularity build metasploit.sif ./metasploit-framework.def
        singulairty run metasplout.sif
