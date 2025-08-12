pipeline {
    agent { label 'built-in' }

    options {
        disableConcurrentBuilds()
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
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Run tests') {
            steps {
                sh '''
                echo "🧹 Czyszczenie katalogów /tmp/robot-* należących do użytkownika: $(whoami)"
                find /tmp -maxdepth 1 -user $(whoami) -type d -name 'robot-*' -exec rm -rf {} + || true

                export HEADLESS=true
                echo "Running in headless mode: $HEADLESS"

                . venv/bin/activate
                robot --outputdir robot_reports \
                --variable HEADLESS:true \
                tests/
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
    }
}
