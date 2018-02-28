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
  call FastqToSam {
	input:
	  ID = element[1] + "-" + element[2],
	  LB = element[5],
	  SM = element[0],
	  PL = element[6],
	  Input_Fastq1 = element[3],
	  Input_Fastq2 = element[4],
	  Unmapped_Basename = unmapped_basename,
	}

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

  call MergeBamAlignment {
	input:
	  ref_fasta_index = ref_fasta_index,
	  Unmapped_Bam = FastqToSam.outputbam,
	  Aligned_Bam = BwaMem.outputfile,
	  ref_dict = ref_dict,
	  ref_fasta = ref_fasta,
	  ref_fasta_index = ref_fasta_index,
	  Output_Bam_Basename = unmapped_basename,
	}
}

call MarkDup {
  input:
	Base_Name = Base_Name + ".markdup.sortsam.bwa",
	Input_File = MergeBamAlignment.output_bam,
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

task FastqToSam {
  File Input_Fastq1
  File Input_Fastq2
  String ID
  String SM
  String LB
  String PL
  String Unmapped_Basename

  command {
	gatk --java-options -Djava.io.tempdir=`pwd`/tmp \
	  FastqToSam \
	  --FASTQ ${Input_Fastq1} \
	  --FASTQ2 ${Input_Fastq2} \
	  -O ${Unmapped_Basename}.bam \
	  --SAMPLE_NAME ${SM} \
	  --READ_GROUP_NAME ${ID} \
	  --LIBRARY_NAME ${LB} \
	  --PLATFORM ${PL} \
	  --SORT_ORDER coordinate \
	  --CREATE_MD5_FILE true
	}
  output {
	File outputbam = "${Unmapped_Basename}.bam"
	File outputbam_md5 = "${Unmapped_Basename}.bam.md5"
  }
  runtime {
	docker: "oskarv/wdl:latest"
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
	  | samtools view -bS - \
	  > ${Base_Name}.bam
  }
  output {
	File outputfile = "${Base_Name}.bam"
  }
  runtime {
	docker: "oskarv/wdl:latest"
  }
}

task MergeBamAlignment {
  File ref_fasta_index
  File Unmapped_Bam
  File Aligned_Bam
  File ref_fasta
  File ref_dict
  String Output_Bam_Basename

  command {
	gatk --java-options -Djava.io.tempdir=`pwd`/tmp \
	  MergeBamAlignment \
	  --VALIDATION_STRINGENCY SILENT \
	  --EXPECTED_ORIENTATIONS FR \
	  --ATTRIBUTES_TO_RETAIN X0 \
	  --ALIGNED_BAM ${Aligned_Bam} \
	  --UNMAPPED_BAM ${Unmapped_Bam} \
	  -O ${Output_Bam_Basename}.bam \
	  --REFERENCE_SEQUENCE ${ref_fasta} \
	  --SORT_ORDER coordinate \
	  --IS_BISULFITE_SEQUENCE false \
	  --ALIGNED_READS_ONLY false \
	  --CLIP_ADAPTERS false \
	  --MAX_RECORDS_IN_RAM 200000 \
	  --ADD_MATE_CIGAR true \
	  --MAX_INSERTIONS_OR_DELETIONS -1 \
	  --PRIMARY_ALIGNMENT_STRATEGY MostDistant \
	  --PROGRAM_RECORD_ID "bwamem" \
	  --PROGRAM_GROUP_VERSION "0.7.12-r1039" \
	  --PROGRAM_GROUP_COMMAND_LINE "bwa mem -t 18 -R -M Input1 Input2 > output.sam" \
	  --PROGRAM_GROUP_NAME "bwamem" \
	  --CREATE_MD5_FILE true
	}
  output {
	File output_bam = "${Output_Bam_Basename}.bam"
	File output_md5 = "${Output_Bam_Basename}.bam.md5"
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
