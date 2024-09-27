pipeline {
    agent any
    
    parameters {
        string(name: 'grafana_domain_name', defaultValue: 'grafana.example.com', description: 'Grafana domain name')
        string(name: 'crashapi_domain_name', defaultValue: 'api.example.com', description: 'Crash API domain name')
        string(name: 'email_user', defaultValue: 'user@example.com', description: 'Email user')
        string(name: 'ssh_credentials_id', defaultValue: 'your-credential-id', description: 'ID of the SSH private key credential')
    }
    
    stages {
        stage("Deploy Main CloudFormation") {
            steps {
                script {
                    // Set AWS credentials
                    withCredentials([string(credentialsId: 'aws_access_key_id', variable: 'aws_access_key_id'), 
                                     string(credentialsId: 'aws_secret_access_key', variable: 'aws_secret_access_key')]) {
                        sh '''
                            aws configure set aws_access_key_id $aws_access_key_id
                            aws configure set aws_secret_access_key $aws_secret_access_key
                            aws configure set default.region us-east-1
                        '''
                    }

                    // Fetch existing CloudFormation stack outputs
                    def output1 = sh(script: 'aws cloudformation describe-stacks --stack-name jenkins-efs-ecs-1 --query "Stacks[0].Outputs"', returnStdout: true).trim()
                    def jsonOutput1 = readJSON(text: output1)

                    // Extract parameters from the stack outputs
                    def VPCID = jsonOutput1.find { it.OutputKey == 'VPCID' }.OutputValue
                    def PublicSubnet1 = jsonOutput1.find { it.OutputKey == 'PublicSubnet1ID' }.OutputValue
                    def PublicSubnet2 = jsonOutput1.find { it.OutputKey == 'PublicSubnet2ID' }.OutputValue

                    // Run AWS CloudFormation create-stack command
                    def createStack = sh(
                        script: """
                            aws cloudformation create-stack --stack-name grafanaPrometheus --template-body file://cloudformation/main.yaml \
                            --parameters ParameterKey=VPCID,ParameterValue=${VPCID} \
                            ParameterKey=PublicSubnet1,ParameterValue=${PublicSubnet1} \
                            ParameterKey=PublicSubnet2,ParameterValue=${PublicSubnet2}
                        """,
                        returnStatus: true
                    )

                    // Check if CloudFormation stack creation was successful
                    if (createStack == 0) {
                        echo "CloudFormation stack creation started successfully."

                        // Wait for the stack creation to complete
                        def waitForStack = sh(
                            script: 'aws cloudformation wait stack-create-complete --stack-name grafanaPrometheus',
                            returnStatus: true
                        )

                        // Check if waiting for stack creation was successful
                        if (waitForStack == 0) {
                            echo "CloudFormation stack creation completed successfully."

                            // Retrieve public IPs of EC2 instances from CloudFormation outputs
                            def output = sh(script: 'aws cloudformation describe-stacks --stack-name grafanaPrometheus --query "Stacks[0].Outputs"', returnStdout: true).trim()
                            def jsonOutput = readJSON(text: output)

                            // Extract IPs from outputs
                            def grafanaIp = jsonOutput.find { it.OutputKey == 'GrafanaPublicIP' }.OutputValue
                            def crashApiIp = jsonOutput.find { it.OutputKey == 'CrashAppPublicIP' }.OutputValue

                            // Create Ansible inventory content
                            def inventoryContent = """
[grafana]
${grafanaIp} ansible_user=ubuntu

[crashapi]
${crashApiIp} ansible_user=ubuntu
"""                          
                            // Write inventory to a file
                            writeFile file: 'ansible/inventory', text: inventoryContent

                        } else {
                            error "Failed to wait for CloudFormation stack creation to complete."
                        }
                    } else {
                        error "Failed to create CloudFormation stack."
                    }
                }
            }
        }
        
        stage("Deploy Grafana, Prometheus, and Crash API Server") {
            steps {
                dir('ansible') {
                    withCredentials([string(credentialsId: 'testkey', variable: 'testKey')]) {
                        // Display inventory
                        def output = sh(script: 'aws cloudformation describe-stacks --stack-name grafanaPrometheus --query "Stacks[0].Outputs"', returnStdout: true).trim()
                        def jsonOutput = readJSON(text: output)
                        def crashApiIp = jsonOutput.find { it.OutputKey == 'CrashAppPublicIP' }.OutputValue
                        sh "cat inventory"
                        // Save private key
                        sh "echo ${testKey} > key.pem"
                        sh "chmod 400 key.pem"
                        // Run Ansible playbook
                        sh """
                            ansible-playbook -i inventory --private-key key.pem \
                            --extra-vars 'crash_api_ip=${crashApiIp} grafana_domain_name=${params.grafana_domain_name} efs_id=fs-0952230233c19bafa crashapi_domain_name=${params.crashapi_domain_name} email_user=${params.email_user}' \
                            main.yaml
                        """
                    }
                }
            }
        }
    }
}
