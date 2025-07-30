pipeline {
    agent any

    environment {
        HEADLESS = 'true'
        REPORT_PATH = 'robot_reports/report.html'
    }

    tools {
        python 'Python 3.12' // dopasuj do lokalnej konfiguracji Jenkinsa
    }

    stages {
        stage('Checkout') {
            steps {
                git credentialsId: 'github-ssh-jenkins', url: 'git@github.com:emil-pelak/CICD_Amazon.git', branch: 'dev/main'
            }
        }

        stage('Setup environment') {
            steps {
                sh '''
                python3 -m venv venv
                source venv/bin/activate
                pip install --upgrade pip
                pip install -r requirements.txt
                '''
            }
        }

        stage('Run tests') {
            steps {
                sh '''
                chmod +x run_tests.sh
                ./run_tests.sh
                '''
            }
        }

        stage('Archive Results') {
            steps {
                archiveArtifacts artifacts: 'robot_reports/**', fingerprint: true
                publishHTML(target: [
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'robot_reports',
                    reportFiles: 'report.html',
                    reportName: 'Robot Test Report'
                ])
            }
        }

        stage('Email Notification') {
            steps {
                mail to: 'twoj.email@domena.pl',
                     subject: "Wyniki testów - Build #${BUILD_NUMBER}",
                     body: "Zakończono testy. Zobacz raport: ${BUILD_URL}robot_reports/report.html"
            }
        }
    }

    post {
        failure {
            mail to: 'twoj.email@domena.pl',
                 subject: "❌ Błąd testów - Build #${BUILD_NUMBER}",
                 body: "Testy nie powiodły się. Sprawdź logi: ${BUILD_URL}console"
        }
    }
}
