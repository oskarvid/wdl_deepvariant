import "deepVariant-ScatterGather.wdl" as deepSG
workflow fastqPreProcessing {
  # Reference files
	File ref_fasta
	File ref_fasta_index
	File ref_dict
	File ref_amb
	File ref_ann
	File ref_bwt
	File ref_pac
	File ref_sa
	Array[File] bedFile

  # Input files
	File inputSamplesFile
  
  # String names  
	String Base_Name = "Base_name"
	String unmapped_basename = "unmapped_bam"

# Preprocess sample input file to remove comments and header for proper scatter gather execution
call FixInputSamplesFile {
  input:
	SamplesFile = inputSamplesFile,
  }

scatter (element in FixInputSamplesFile.FixedSamplesFile) {
  call BwaMem {
	input:
	  ref_fasta = ref_fasta,
	  ref_fasta_index = ref_fasta_index,
	  ref_dict = ref_dict,
	  ref_bwt = ref_bwt,
	  ref_amb = ref_amb,
	  ref_ann = ref_ann,
	  ref_pac = ref_pac,
	  ref_sa = ref_sa,
	  ID = element[1] + "-" + element[2],
	  LB = element[5],
	  SM = element[0],
	  PL = element[6],
	  Input_Fastq1 = element[3],
	  Input_Fastq2 = element[4],
	  Base_Name = Base_Name + ".bwa",
	}
}

call MarkDup {
  input:
	Base_Name = Base_Name + ".markdup.sortsam.bwa",
	Input_File = BwaMem.outputfile,
  }

call deepSG.deepVariant {
	input: 
          ref_fasta = ref_fasta,
          ref_fasta_index = ref_fasta_index,
          input_bam = MarkDup.MarkDupOutputBam,
          input_bai = MarkDup.MarkDupOutputBai,
          bedFile = bedFile,
}

}

# Preprocess sample input file to remove comments and header for proper scatter gather execution
task FixInputSamplesFile {
  File SamplesFile

  command {
	grep -v "#" ${SamplesFile} | grep -v "SAMPLE" > /dev/stdout
  }
  output {
	Array[Array[String]] FixedSamplesFile = read_tsv(stdout())
  }
}

task BwaMem {
  File Input_Fastq1
  File Input_Fastq2
  File ref_fasta
  File ref_fasta_index
  File ref_dict
  File ref_amb
  File ref_ann
  File ref_bwt
  File ref_pac
  File ref_sa
  String ID
  String SM
  String LB
  String PL
  String Base_Name
  
  command {
	bwa mem -t 8 \
	  -R "@RG\tID:${ID}\tSM:${SM}\tLB:${LB}\tPL:${PL}\tPU:NotDefined" \
	  -M ${ref_fasta} ${Input_Fastq1} ${Input_Fastq2} \
	  | gatk --java-options -Djava.io.tempdir=`pwd`/tmp \
          SortSam -I /dev/stdin -O ${Base_Name}.bam -SO coordinate 
  }
  output {
	File outputfile = "${Base_Name}.bam"
  }
  runtime {
	docker: "oskarv/wdl:latest"
  }
}

task MarkDup {
  Array[File] Input_File
  String Base_Name

  command {
	gatk --java-options -Djava.io.tempdir=`pwd`/tmp \
	  MarkDuplicates \
	  --INPUT ${sep=' --INPUT=' Input_File} \
	  -O ${Base_Name}.bam \
	  --VALIDATION_STRINGENCY LENIENT \
	  --METRICS_FILE ${Base_Name}.metrics \
	  --MAX_FILE_HANDLES_FOR_READ_ENDS_MAP 200000 \
	  --CREATE_INDEX true \
	  --CREATE_MD5_FILE true
	}
  output {
	File MarkDupOutputBam = "${Base_Name}.bam"
	File MarkDupOutputBam_md5 = "${Base_Name}.bam.md5"
	File MarkDupOutputBai = "${Base_Name}.bai"
	File MetricsFile = "${Base_Name}.metrics"
  }
  runtime {
	docker: "oskarv/wdl:latest"
  }
}
