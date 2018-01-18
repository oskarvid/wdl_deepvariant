workflow deepVariant {
  # Reference files
	File ref_fasta
	File ref_fasta_index
	File ref_dict
	File ref_amb
	File ref_ann
	File ref_bwt
	File ref_pac
	File ref_sa

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

# Create list of sequences for scatter-gather parallelization 
call CreateSequenceGroupingTSV {
  input:
	ref_dict = ref_dict,
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

call make_examples {
  input:
  	ref_fasta = ref_fasta,
  	ref_fasta_index = ref_fasta_index,
	InputBam = MarkDup.MarkDupOutputBam,
	InputBai = MarkDup.MarkDupOutputBai,
	Examples = "examples",
  }

call call_variants {
  input:
    CallVariantsOutput = "called_variants_raw",
  	Examples = make_examples.ExamplesOutput,
  }

call post_process {
  input:
  	ref_fasta = ref_fasta,
  	ref_fasta_index = ref_fasta_index,
	InputFile = call_variants.CallOutput,
	FinalOutput = "deepVariant",
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

# Generate sets of intervals for scatter-gathering over chromosomes
task CreateSequenceGroupingTSV {
  File ref_dict

# Use python to create the Sequencing Groupings used for BQSR and PrintReads Scatter. 
# It outputs to stdout where it is parsed into a wdl Array[Array[String]]
# e.g. [["1"], ["2"], ["3", "4"], ["5"], ["6", "7", "8"]]
  command <<<
    python <<CODE
    with open("${ref_dict}", "r") as ref_dict_file:
        sequence_tuple_list = []
        longest_sequence = 0
        for line in ref_dict_file:
            if line.startswith("@SQ"):
                line_split = line.split("\t")
                # (Sequence_Name, Sequence_Length)
                sequence_tuple_list.append((line_split[1].split("SN:")[1], int(line_split[2].split("LN:")[1])))
        longest_sequence = sorted(sequence_tuple_list, key=lambda x: x[1], reverse=True)[0][1]
    # We are adding this to the intervals because hg38 has contigs named with embedded colons (:) and a bug in 
    # some versions of GATK strips off the last element after a colon, so we add this as a sacrificial element.
    hg38_protection_tag = ":1+"
    # initialize the tsv string with the first sequence
    tsv_string = sequence_tuple_list[0][0] + hg38_protection_tag
    temp_size = sequence_tuple_list[0][1]
    for sequence_tuple in sequence_tuple_list[1:]:
        if temp_size + sequence_tuple[1] <= longest_sequence:
            temp_size += sequence_tuple[1]
            tsv_string += "\t" + sequence_tuple[0] + hg38_protection_tag
        else:
            tsv_string += "\n" + sequence_tuple[0] + hg38_protection_tag
            temp_size = sequence_tuple[1]
    # add the unmapped sequences as a separate line to ensure that they are recalibrated as well
    with open("sequence_grouping.txt","w") as tsv_file:
      tsv_file.write(tsv_string)
      tsv_file.close()

    tsv_string += '\n' + "unmapped"

    with open("sequence_grouping_with_unmapped.txt","w") as tsv_file_with_unmapped:
      tsv_file_with_unmapped.write(tsv_string)
      tsv_file_with_unmapped.close()
    CODE
  >>>
  output {
	Array[Array[String]] sequence_grouping = read_tsv("sequence_grouping.txt")
	Array[Array[String]] sequence_grouping_with_unmapped = read_tsv("sequence_grouping_with_unmapped.txt")
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
	bwa mem -t 3 \
	  -R "@RG\tID:${ID}\tSM:${SM}\tLB:${LB}\tPL:${PL}\tPU:NotDefined" \
	  -M ${ref_fasta} ${Input_Fastq1} ${Input_Fastq2} > ${Base_Name}.sam
  }
  output {
	File outputfile = "${Base_Name}.sam"
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
}

task make_examples {
	File InputBam
	File InputBai
	File ref_fasta
	File ref_fasta_index
	String Examples

	command {
		python /home/bin/make_examples.zip \
		--mode calling \
		--ref ${ref_fasta} \
		--reads ${InputBam} \
		--examples ${Examples}.tfrecord.gz
	}
	output {
		File ExamplesOutput = "${Examples}.tfrecord.gz"
	}
    runtime {
      docker: "dajunluo/deepvariant"
    }
}

task call_variants {
	File Examples
	String CallVariantsOutput

	command {
		python /home/bin/call_variants.zip \
		--outfile ${CallVariantsOutput}.tfrecord.gz \
		--examples ${Examples} \
		--checkpoint /home/models/model.ckpt
	}
	output {
		File CallOutput = "${CallVariantsOutput}.tfrecord.gz"
	}
    runtime {
      docker: "dajunluo/deepvariant"
    }
}

task post_process {
	File ref_fasta
	File ref_fasta_index
	File InputFile
	String FinalOutput

	command {
		python /home/bin/postprocess_variants.zip \
		--ref ${ref_fasta} \
		--infile ${InputFile} \
		--outfile ${FinalOutput}.vcf.gz
	}
	output {
		File Output = "${FinalOutput}.vcf.gz"
	}
    runtime {
      docker: "dajunluo/deepvariant"
    }
}

