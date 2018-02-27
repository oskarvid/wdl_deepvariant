### DeepVariant wdl based pipeline  
(This pipeline is for testing purposes only, tread with caution)

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

There are two pipeline start scripts, one to start a pipeline that takes fastq files as input and one that takes a bam file as input, for the
same reason there's two wdl scripts as well. The full pipeline uses the tsv file in the inputs folder to define the input files, the pipeline
supports correct creation of read groups, and this data is entered into the tsv file and parsed by the wdl script. The deepvariant wdl file
takes a bam file as input, this is defined in the .json file. 
