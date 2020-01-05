#!/usr/bin/env bash

shopt -s failglob
set -eu -o pipefail

PIPELINE_STACK_NAME="react-node-serverless-demo-codepipeline-stack"

echo "Checking if stack exists ..."

if ! aws cloudformation describe-stacks --stack-name "$PIPELINE_STACK_NAME" --profile personal; then

  echo -e "\nStack does not exist, creating ..."
  aws cloudformation create-stack \
    --stack-name "$PIPELINE_STACK_NAME" \
    --capabilities CAPABILITY_IAM \
    --parameters ParameterKey=GitHubOAuthToken,ParameterValue=$GITHUB_OAUTH_TOKEN \
    --template-body file://pipeline.yml --profile personal

  echo "Waiting for stack to be created ..."
  aws cloudformation wait stack-create-complete \
    --stack-name "$PIPELINE_STACK_NAME" --profile personal

else

  echo -e "\nStack exists, attempting update ..."

  set +e
  update_output=$( aws cloudformation update-stack \
    --stack-name "$PIPELINE_STACK_NAME" \
    --capabilities CAPABILITY_IAM \
    --parameters ParameterKey=GitHubOAuthToken,ParameterValue=$GITHUB_OAUTH_TOKEN \
    --template-body file://pipeline.yml --profile personal \
    2>&1)
  status=$?
  set -e

  echo "$update_output"

  if [ $status -ne 0 ] ; then

    # Don't fail for no-op update
    if [[ $update_output == *"ValidationError"* && $update_output == *"No updates"* ]] ; then
      echo -e "\nFinished create/update - no updates to be performed"
      exit 0
    else
      exit $status
    fi

  fi

  echo "Waiting for stack update to complete ..."
  aws cloudformation wait stack-update-complete \
    --stack-name "$PIPELINE_STACK_NAME" --profile personal

fi

echo "Finished create/update successfully!"
