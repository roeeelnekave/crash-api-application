pipeline{
    agent { label 'ansible' }
    stages{
        stage("deploy main cloud formation")
        {
            steps {
                script {
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
                        } else {
                            error "Failed to wait for CloudFormation stack creation to complete."
                        }
                    } else {
                        error "Failed to create CloudFormation stack."
                    }
                }
            }
        }
        stage("deploy grafana, promethues and crash api server")
        {
            steps{
               dir('ansible'){
                sh "chmod 400 TestKey.pem"
                sh "ansible-playbook -i inventory --private-key TestKey.pem main.yml"
               }
            }

        }
    }
}


