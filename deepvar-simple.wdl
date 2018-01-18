workflow deepVariant {
	File ReferenceFasta
	File ReferenceFai
	File InputBam
	File InputBai
	
call make_examples {
  input:
  	ReferenceFasta = ReferenceFasta,
  	ReferenceFai = ReferenceFai,
	InputBam = InputBam,
	InputBai = InputBai,
	Examples = "examples",
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
	FinalOutput = "deepVariant",
	}
}

task make_examples {
	File InputBam
	File InputBai
	File ReferenceFasta
	File ReferenceFai
	String Examples

	command {
		seq 0 4 | \
		parallel --eta --halt 2 \
		python /home/bin/make_examples.zip \
		--mode calling \
		--ref ${ReferenceFasta} \
		--reads ${InputBam} \
		--examples ${Examples}.tfrecord@4.gz \
		--regions "1:1-90,010,000" \
		--task {}
	}
	output {
		File ExamplesOutput1 = "${Examples}.tfrecord1.gz"
		File ExamplesOutput2 = "${Examples}.tfrecord2.gz"
		File ExamplesOutput3 = "${Examples}.tfrecord3.gz"
		File ExamplesOutput4 = "${Examples}.tfrecord4.gz"
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
		--outfile ${CallVariantsOutput} \
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
	File ReferenceFasta
	File ReferenceFai
	File InputFile
	String FinalOutput

	command {
		python /home/bin/postprocess_variants.zip \
		--ref ${ReferenceFasta} \
		--infile ${InputFile} \
		--outfile ${FinalOutput}
	}
	output {
		File Output = "${FinalOutput}.vcf.gz"
	}
    runtime {
      docker: "dajunluo/deepvariant"
    }
}

