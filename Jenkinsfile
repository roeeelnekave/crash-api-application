pipeline {
    agent { label 'ansible' }
    
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
                    withCredentials([string(credentialsId: 'aws_access_key_id', variable: 'aws_access_key_id'), string(credentialsId: 'aws_secret_access_key', variable: 'aws_secret_access_key')]) {
                    sh '''
                        aws configure set aws_access_key_id $aws_access_key_id
                        aws configure set aws_secret_access_key $aws_secret_access_key
                        aws configure set default.region us-east-1
                    '''
    // some block
                     }
                    // Run the AWS CloudFormation create-stack command
                    def createStack = sh(
                        script: 'aws cloudformation create-stack --stack-name grafanaPrometheus --template-body file://cloudeformation/main.yaml',
                        returnStatus: true
                    )

                    // Check if the create-stack command was successful
                    if (createStack == 0) {
                        echo "CloudFormation stack creation started successfully."

                        // Wait for the stack creation to complete
                        def waitForStack = sh(
                            script: 'aws cloudformation wait stack-create-complete --stack-name grafanaPrometheus',
                            returnStatus: true
                        )

                        // Check if the wait command was successful
                        if (waitForStack == 0) {
                            echo "CloudFormation stack creation completed successfully."
                            
                            // Retrieve public IPs of EC2 instances from CloudFormation outputs
                            def output = sh(script: 'aws cloudformation describe-stacks --stack-name grafanaPrometheus --query "Stacks[0].Outputs"', returnStdout: true).trim()
                            def jsonOutput = readJSON(text: output)

                            // Extract IPs from outputs
                            def grafanaIp = jsonOutput.find { it.OutputKey == 'GrafanaPublicIP' }.OutputValue
                            def crashApiIp = jsonOutput.find { it.OutputKey == 'CrashAppPublicIP' }.OutputValue
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
                        sh "echo ${testKey} > key.pem"
                        sh "chmod 400 key.pem"
                        sh """
                            ansible-playbook -i inventory --private-key key.pem --extra-vars 'crash_api_ip=${crashApiIp} grafana_domain_name=${params.grafana_domain_name} efs_id=fs-0952230233c19bafa crashapi_domain_name=${params.crashapi_domain_name} email_user=${params.email_user}' main.yaml
                        """
                    }
                }
            }
        }
    }
}