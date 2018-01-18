curl -X POST --header "Accept: application/json" "http://localhost:8000/api/workflows/v1/batch" \
	-F workflowSource=@deepvar-simple.wdl \
	-F workflowInputs=@deepvar-simple.json \
	-F workflowOptions=@cromwell-mysql/cromwell/workflow-options/workflowoptions.json
