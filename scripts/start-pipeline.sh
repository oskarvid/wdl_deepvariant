curl -X POST --header "Accept: application/json" "http://localhost:8000/api/workflows/v1/batch" \
	-F workflowSource=@deepVariant.wdl \
	-F workflowInputs=@deepVariant.json \
	-F workflowOptions=@cromwell-mysql/cromwell/workflow-options/workflowoptions.json
