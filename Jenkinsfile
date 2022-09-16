pipeline {

  parameters {
    string(name: 'stack_name', defaultValue : 'testsg11', description: "Stack Name")
    string(name: 'SNSNameCustomer01', defaultValue : 'nvsgissnssg11', description: "SNS Topic Name")
    string(name: 'SNSEmailEndpointCustomer01', defaultValue : 'abc@xyz.com', description: "Subscription Email Address")
    string(name: 'AWSAcccountName', defaultValue : 'RCCSBX11', description: "AWS Account name Ex RCCSBX ..")
    string(name: 'IAMRoleForLambda', defaultValue : 'RRCCSBX_AWS_AWSSG11', description: "IAM Role Name")
    string(name: 'IAMPolicyForLambda', defaultValue : 'PRCCSBXAWSAWSSG11', description: "IAM Policy Name")
    string(name: 'CWEventRuleName', defaultValue : 'CWRCCSBXSG11', description: "Cloud Watch Event Rule Name")
    string(name: 'CWEventRuleName', defaultValue : 'CWRCCSBXSG11', description: "Cloud Watch Event Rule Name")
  }

  options {
    disableConcurrentBuilds()
    timeout(time: 1, unit: 'HOURS')
    withAWS(credentials: params.credential, region: params.region)
    ansiColor('xterm')
  }

  agent { label 'master' }

  stages {

    stage('Setup') {
      steps {
        script {
          currentBuild.displayName = "#" + env.BUILD_NUMBER + "-" + params.stack_name
        }
      }
    }

    stage('CheckOut SCM') {
        steps {
        checkout changelog: false, poll: false, scm: [$class: 'GitSCM', branches: [[name: '*/main']], 
        doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], 
        userRemoteConfigs: [[url: 'https://github.com/venkat0550/cft-create-stack.git']]]
        }
      }
	
    stage('Validate Template') {
      steps {
        script {
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: 'rcc-sbx', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]){ 
            sh '''
              val=$(aws cloudformation validate-template --template-body file://sg1.json --region us-east-1 &> /dev/null)

              if [[ "$?" != 0 ]]; then
                      echo "the template is not valid - Please check"
                  exit 1
              else
                  echo "the template is valid"
              fi

              aws cloudformation get-template-summary --template-body file://sg1.json --region us-east-1 > out.json
              cat out.json
            '''
          }
        }
      }
    }

    stage("Construct Parameters"){
      steps{
          script{
                def sns = params.SNSNameCustomer01
                def email = params.SNSEmailEndpointCustomer01
                def acc = params.AWSAcccountName
                def role = params.IAMRoleForLambda
                def policy = params.IAMPolicyForLambda
                def event = params.CWEventRuleName
                echo "sns"
                sh '''
                  JSON_STRING=`jq -n \
                                    --arg snsa '''+sns+'''\
                                    --arg emaila '''+email+''' \
                                    --arg acca '''+acc+''' \
                                    --arg rolea '''+role+''' \
                                    --arg policya '''+policy+''' \
                                    --arg eventa '''+event+''' \
                            ' [{"ParameterKey": "SNSNameCustomer01","ParameterValue": $snsa},{"ParameterKey":"SNSEmailEndpointCustomer01","ParameterValue": $emaila},{"ParameterKey":"AWSAcccountName","ParameterValue": $acca},{"ParameterKey": "IAMRoleForLambda","ParameterValue": $rolea},{"ParameterKey": "IAMPolicyForLambda","ParameterValue":$policya},{"ParameterKey": "CWEventRuleName","ParameterValue":$eventa}] '`
                  echo $JSON_STRING > param1.json
                  cat param1.json
                '''
          }
      }
    }

    stage('Check if the stack is already exists') {
      steps {
            script {
                    def stack_name = params.stack_name
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: 'rcc-sbx', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]){ 
                    def stack_status = sh(returnStatus: true, script: "aws cloudformation describe-stacks --stack-name $stack_name --output text --region us-east-1 &> /dev/null")

                    if (stack_status != 0) {
                    currentBuild.result = 'SUCCESS'
                    echo "Proceed for stack creation"
                    }else{
                        echo "can't be proceed stack is already there" 
                        currentBuild.result = 'FAILURE'
                        error 'cant proceed'
                    }

                 }
              }
      }
    }

    stage('Proceed to Create Stack') {
      steps {
        script {
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: 'rcc-sbx', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]){ 
            sh '''
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
            '''
          }
        }
      }
    }
    

    stage('Result') {
      steps {
        script {
          currentBuild.displayName = "#" + env.BUILD_NUMBER + "- " + currentBuild.result + "-" + params.stack_name
        }
      }
    }
  }

}
