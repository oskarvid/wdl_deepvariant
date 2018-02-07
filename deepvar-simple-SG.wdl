workflow deepVariant {
	File ReferenceFasta
	File ReferenceFai
	File InputBam
	File InputBai
	Array[File] bedFile

  scatter (subInterval in bedFile){
	call make_examples {
	  input:
		ReferenceFasta = ReferenceFasta,
		ReferenceFai = ReferenceFai,
		InputBam = InputBam,
		InputBai = InputBai,
		Examples = "examples",
		BedFile = subInterval,
	  }

	call call_variants {
	  input:
		CallVariantsOutput = "called_variants_raw",
		Examples = make_examples.ExamplesOutput,
	  }

	call post_process {
	  input:
		ReferenceFasta = ReferenceFasta,
		ReferenceFai = ReferenceFai,
		InputFile = call_variants.CallOutput,
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
	File InputBam
	File InputBai
	File ReferenceFasta
	File ReferenceFai
	String Examples

	command<<<
	bash <<CODE
		python /home/bin/make_examples.zip \
		--mode calling \
		--ref ${ReferenceFasta} \
		--reads ${InputBam} \
		--examples ${Examples}.tfrecord.gz \
		--regions ${sep=" --regions " BedFile}
	CODE
		>>>
	output {
		File ExamplesOutput = "${Examples}.tfrecord.gz"
	}
    runtime {
      docker: "dajunluo/deepvariant"
      continueOnReturnCode: [0, 1]
    }
}

task call_variants {
	File Examples
	String CallVariantsOutput

	command<<<
	bash <<CODE
		python /home/bin/call_variants.zip \
		--outfile ${CallVariantsOutput}.tfrecord.gz \
		--examples ${Examples} \
		--checkpoint /home/models/model.ckpt
	CODE
		>>>
	output {
		File CallOutput = "${CallVariantsOutput}.tfrecord.gz"
	}
    runtime {
      docker: "dajunluo/deepvariant"
      continueOnReturnCode: [0, 1]
    }
}

task post_process {
	File ReferenceFasta
	File ReferenceFai
	File InputFile
	String FinalOutput

	command {
		python /home/bin/postprocess_variants.zip \
		--ref ${ReferenceFasta} \
		--infile ${InputFile} \
		--outfile ${FinalOutput}.vcf.gz
	}
	output {
		File Output = "${FinalOutput}.vcf.gz"
	}
    runtime {
      docker: "dajunluo/deepvariant"
      continueOnReturnCode: [0, 1]
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
