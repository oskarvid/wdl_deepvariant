curl -X POST --header "Accept: application/json" "http://localhost:8000/api/workflows/v1/batch" \
	-F workflowSource=@fullPipeline.wdl \
	-F workflowInputs=@fullPipeline.json \
	-F workflowOptions=@cromwell-mysql/cromwell/workflow-options/workflowoptions.json
