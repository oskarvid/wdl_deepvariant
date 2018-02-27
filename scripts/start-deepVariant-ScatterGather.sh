curl -X POST --header "Accept: application/json" "http://localhost:8000/api/workflows/v1/batch" \
	-F workflowSource=@deepVariant-ScatterGather.wdl \
	-F workflowInputs=@deepVariant-ScatterGather.json \
	-F workflowOptions=@cromwell-mysql/cromwell/workflow-options/workflowoptions.json
