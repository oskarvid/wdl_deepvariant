workflow deepVariant {
	File ref_fasta
	File ref_fasta_index
	File input_bam
	File input_bai
	Array[File] bedFile

  scatter (subInterval in bedFile){
	call make_examples {
	  input:
	      ref_fasta = ref_fasta,
	      ref_fasta_index = ref_fasta_index,
	      input_bam = input_bam,
	      input_bai = input_bai,
	      Examples = "examples",
	      BedFile = subInterval,
	  }
  }

	call call_variants {
	  input:
	    CallVariantsOutput = "called_variants_raw",
	    Examples = make_examples.ExamplesOutput,
	  }

  scatter (file in call_variants.CallOutput){
	call post_process {
	  input:
	    ref_fasta = ref_fasta,
	      ref_fasta_index = ref_fasta_index,
	      InputFile = file,
	      FinalOutput = "deepVariant_raw",
	  }
  }

# Combine GVCFs into a single sample GVCF file
call GatherVCFs {
  input:
	Input_Vcfs = post_process.Output,
	Output_Vcf_Name = "DeepVariantFinal",
  }
}

task make_examples {
	Array[File] BedFile
	File input_bam
	File input_bai
	File ref_fasta
	File ref_fasta_index
	String Examples

	command {
		python /home/bin/make_examples.zip \
		--mode calling \
		--ref ${ref_fasta} \
		--reads ${input_bam} \
		--examples ${Examples}.tfrecord.gz \
		--regions ${sep=" --regions " BedFile}
        }

	output {
		File ExamplesOutput = "${Examples}.tfrecord.gz"
	}
    runtime {
      docker: "dajunluo/deepvariant:latest"
    }
}

task call_variants {
	Array[File] Examples
	String CallVariantsOutput

	command {
	i=0 && \
	for file in ${sep=' ' Examples}; do
		let "i++"
		python /home/bin/call_variants.zip \
		--outfile file-$i.tfrecord.gz \
		--examples $file \
		--checkpoint /home/models/model.ckpt
	done
        }

	output {
		Array[File] CallOutput = glob("file-*.tfrecord.gz")
	}
    runtime {
      docker: "dajunluo/deepvariant:latest"
    }
}

task post_process {
	File ref_fasta
	File ref_fasta_index
	Array[File] InputFile
	String FinalOutput

	command {
		python /home/bin/postprocess_variants.zip \
		--ref ${ref_fasta} \
		--infile ${sep=' ' InputFile} \
		--outfile ${FinalOutput}.vcf.gz
	}

	output {
		File Output = "${FinalOutput}.vcf.gz"
	}
    runtime {
      docker: "dajunluo/deepvariant:latest"
    }
}

task GatherVCFs {
  Array[File] Input_Vcfs
  String Output_Vcf_Name

  command {
	gatk --java-options -Djava.io.tempdir=`pwd`/tmp \
	  MergeVcfs \
	  -I ${sep=" -I " Input_Vcfs} \
	  -O ${Output_Vcf_Name}.vcf.gz \
	  --CREATE_INDEX true
  }

  output {
	File output_vcfs = "${Output_Vcf_Name}.vcf.gz"
  }
    runtime {
      docker: "oskarv/wdl"
    }
}
