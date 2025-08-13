pipeline {
    agent { label 'built-in' }   // Built-In Node

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        HEADLESS = 'true'
    }

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
                  pip install --upgrade pip
                  pip install -r requirements.txt
                '''
            }
        }

        stage('Run tests') {
            steps {
                sh '''
                  echo "🧹 Czyszczenie /tmp/robot-* (tylko właściciel: $(whoami))"
                  find /tmp -maxdepth 1 -user $(whoami) -type d -name 'robot-*' -exec rm -rf {} + || true

                  echo "HEADLESS=$HEADLESS"
                  . venv/bin/activate
                  robot --outputdir robot_reports \
                        --variable HEADLESS:$HEADLESS \
                        tests/
                '''
            }
        }

        stage('Publish report') {
            steps {
                publishHTML([
                    allowMissing: true,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'robot_reports',
                    reportFiles: 'report.html',
                    reportName: 'Robot Report'
                ])
                archiveArtifacts artifacts: 'robot_reports/*', fingerprint: true, allowEmptyArchive: true
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished.'
        }
    }
}
