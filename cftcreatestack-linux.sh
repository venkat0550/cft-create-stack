#!/bin/bash

stack_name="$1"
SNSNameCustomer01="$2"
SNSEmailEndpointCustomer01="$3"
AWSAcccountName="$4"
IAMRoleForLambda="$5"
IAMPolicyForLambda="$6"
CWEventRuleName="$7"

if [ -z $stack_name ]; then
	echo "Missing stack name"
	exit 1
fi

if [ $# -ne 7 ]; then
	echo "Missing the parameters"
	exit 1
fi

JSON_STRING=$( jq -n \
                  --arg sns "$SNSNameCustomer01" \
                  --arg email "$SNSEmailEndpointCustomer01" \
                  --arg acc "$AWSAcccountName" \
				  --arg role "$IAMRoleForLambda" \
                  --arg policy "$IAMPolicyForLambda" \
                  --arg event "$CWEventRuleName" \
				  ' [{"ParameterKey": "SNSNameCustomer01","ParameterValue": $sns},{"ParameterKey":"SNSEmailEndpointCustomer01","ParameterValue": $email},{"ParameterKey":"AWSAcccountName","ParameterValue": $acc},{"ParameterKey": "IAMRoleForLambda","ParameterValue": $role},{"ParameterKey": "IAMPolicyForLambda","ParameterValue":$policy},{"ParameterKey": "CWEventRuleName","ParameterValue":$event}] ')

echo $JSON_STRING > param1.json

echo "The given stack name is - $stack_name "
echo "Validating the template now ....."

val=$(aws cloudformation validate-template --template-body file://sg1.json --region us-east-1 &> /dev/null)

if [[ "$?" != 0 ]]; then
        echo "the template is not valid - Please check"
		exit 1
else
		echo "the template is valid"
fi

echo "Proceeding to check if the stack name is already exists..."

desc_stack=$(aws cloudformation describe-stacks --stack-name $stack_name --output text --query "Stacks[].StackStatus" --region us-east-1 &> /dev/null)

if [[ "$?" = 0 ]]; then
        echo "The stack $stack_name is already present - No action can be performed"
        exit 1
else
        echo "stack $stack_name can be created"
fi

echo "Template summary before creating resources"

aws cloudformation get-template-summary --template-body file://sg1.json --region us-east-1 > out.json

cat out.json

read -p "Are you sure? " -n 1 -r
echo -e "\n"
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

echo "creating New stack - $stack_name ...."

stack_id=$(aws cloudformation create-stack --stack-name $stack_name --template-body file://sg1.json  --parameters file://param1.json --capabilities CAPABILITY_NAMED_IAM --region us-east-1  --output text --query "StackId")

echo "stack id - $stack_id"

while true
do
  state=$(aws cloudformation describe-stacks --stack-name $stack_name --output text --query "Stacks[].StackStatus" --region us-east-1)
  if [[ "$state" = "CREATE_IN_PROGRESS" ]]; then
	echo "Status - $state "
	sleep 20
  elif [[ "$state" == "CREATE_COMPLETE" ]]; then
    echo "$state - stack $stack_name created success"
	aws cloudformation describe-stack-resources --stack-name $stack_name --output json --query "StackResources[].{logical: LogicalResourceId, physical: PhysicalResourceId }" --region us-east-1 > out1.json
	cat out1.json
    break
  elif [[ "$state" == "ROLLBACK_IN_PROGRESS" ]]; then
    echo "Status - $state - The Stack $stack_name is having difficulty to create resources - Please check"
	sleep 20
  elif [[ "$state" == "ROLLBACK_COMPLETE" || "$state" == "ROLLBACK_FAILED" ]]; then
    echo "Status - $state - The Stack $stack_name is having difficulty to create resources - Please check"
	sleep 20
	break
  else
    echo "----"
  fi
done

echo "Result - $state"


