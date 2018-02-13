### DeepVariant wdl based pipeline  
(This pipeline is only for testing purposes, there are probably resources usage issues with call variants, tread with caution)

## Downloading the reference files  
The default reference fasta is the hg38 fasta file from the Broad Institute, they host it at their public ftp server here: ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg38  
There is no password. You can automatically download the hg38 fasta and fasta index files with the following command:  
wget ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg38/{Homo_sapiens_assembly38.fasta.gz,Homo_sapiens_assembly38.fasta.fai}


## Setup instructions
These three scripts need to be executed in the following order to start the pipeline.  
1. sh scripts/start-mysql-server.sh  
2. sh scripts/start-cromwell-server.sh  
3. sh scripts/start-pipeline.sh  

Before setting up the MySQL and cromwell servers it's a good idea to index the fasta file with bwa since it's a very time consuming process. Just run "bwa index -a bwtsw filename.fasta" and continue with the steps below.

If you simply run the start-mysql-server.sh script it will download the required mysql:5.7 docker image automatically. You might want to edit the username and password in the cromwell-mysql/mysql/init_user.sql file, the default is set to cromwell for both. If you edit the init_user.sql file, you also need to edit the cromwell-mysql/cromwell/application.conf file and set the correct username and password so cromwell can log in to the MySQL database.  

You also need to run "sudo docker ps -a" and copy the container ID of the MySQL docker container, e.g "3da13d9f19b0", then run "docker inspect 3da13d9f19b0 | grep IPA" and copy the IP address and paste it in the application.conf file that is located at cromwell-mysql/cromwell/config/. Towards the bottom of the file there is an IP address that points to the MySQL database, replace it with your copied IP address.  
Before you can run the start-cromwell.sh script, you need to run "sh scripts/dl-cromwell.sh" to automatically download cromwell to the tools directory. Now you can finally run "sh scripts/start-cromwell-server.sh".

Now that the MySQL and cromwell servers are up and running, you need to edit the appropriate .json file for the pipeline version you want to run, e.g deepVariant.json for the complete pipeline. Edit the file paths for each file, also go to the inputs/template_sample_manifest.tsv file, enter the correct file paths for the input files, and once that's done you can finally run "sh scripts/start-pipeline.sh" script.

There are currently three start pipeline scripts, one for the full version, one for the "simple.wdl" that starts with a bam file as input and uses GNU parallel for parallelization. This version is not planned to be long lived but this has still not been definitively decided.  
The third start script will start with a bam file and run the deepvariant tools with scatter gather parallelization. The scatter gather version has not been tested enough yet, but it seems like each shard will get 16 threads in the call variants step, thus if you only have 16 cores and are running two or more shards, you will overload your machine. Tread with caution, this is still only for testing purposes.