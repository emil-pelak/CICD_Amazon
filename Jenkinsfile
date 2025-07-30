pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install dependencies') {
            steps {
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Run tests') {
            steps {
                sh '''
                    . venv/bin/activate
                    robot --outputdir robot_reports tests/
                '''
            }
        }

        stage('Publish report') {
            steps {
                publishHTML([
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'robot_reports',
                    reportFiles: 'report.html',
                    reportName: 'Amazon Test Report'
                ])
            }
        }

        stage('Send email') {
            steps {
                mail to: 'emil-pelak@outlook.com',
                     subject: "Amazon UI Tests - Build ${env.BUILD_NUMBER}",
                     body: "Wyniki testów dostępne w Jenkinsie: ${env.BUILD_URL}"
            }
        }
    }
}
