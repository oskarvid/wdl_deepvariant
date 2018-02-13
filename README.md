### DeepVariant wdl based pipeline  
(This is still a rough draft)

## Downloading the reference files  
The default reference fasta is the hg38 fasta file from the Broad Institute, they host it at their public ftp server here: ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg38  
There is no password. You can automatically download the hg38 fasta and fasta index files with the following command:  
wget ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg38/{Homo_sapiens_assembly38.fasta.gz,Homo_sapiens_assembly38.fasta.fai}


## Setup instructions
These three scripts need to be executed in the following order to start the pipeline.  
1. sh scripts/start-mysql-server.sh  
2. sh scripts/start-cromwell-server.sh  
3. sh scripts/start-pipeline.sh  

If you simply run the start-mysql-server.sh script it will download the required mysql:5.7 docker image automatically. You might want to edit the username and password in the cromwell-mysql/mysql/init_user.sql file, the default is set to cromwell for both. If you edit the init_user.sql file, you also need to edit the cromwell-mysql/cromwell/application.conf file and set the correct username and password so cromwell can log in to the MySQL database.  

The second step is setting up the start-cromwell-server.sh script. As long as you run the pipeline from the "wdl_pipeline" directory you only need to edit "REFERENCE", which is the directory where your reference files are located. You also need to run "sudo docker ps -a" and copy the container ID of the MySQL docker container, e.g "3da13d9f19b0", then run "docker inspect 3da13d9f19b0 | grep IPA" and copy the IP address and paste it in the application.conf file that is located at cromwell-mysql/cromwell/config/. Towards the bottom of the file there is an IP address that points to the MySQL database, replace it with your copied IP address.  
Before you can run the start-cromwell.sh script, you need to run "sh scripts/dl-cromwell.sh" to automatically download cromwell to the tools directory. Now you can finally run "sh scripts/start-cromwell-server.sh".

Now that the MySQL and cromwell servers are up and running, you can run "sh scripts/start-pipeline.sh" script. It will by default use the fastq files that are in the data directory.

There are currently three start pipeline scripts, one for the full version, one for the "simple.wdl" that starts with a bam file as input and uses GNU parallel for parallelization. This version is not planned to be long lived but this has still not been definitively decided.  
The third start script will start with a bam file and run the deepvariant tools with scatter gather parallelization, unfortunately there seems to be a bug that causes "call_variants" to use as many threads per process as there are shards in the scatter gather operation.  
I.e if there are 16 shards, there will potentially be 16*16 threads used by call_variants. The expected behavior is that each call_variants process will only use one thread, and not as many threads as there are shards _per shard_. Hence if you have a 16 thread system, 4 shards should at most use 4*4 threads. On the other hand this limits the resource usage to only a fourth of the cores during the "make_calls" stage, which is a very demanding and long process. 

I will investigate this further when I get the opportunity.
