pipeline {
    agent any

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
                echo "🧹 Czyszczenie starych katalogów /tmp/robot-*"
                find /tmp -maxdepth 1 -type d -name 'robot-*' -exec rm -rf {} + || true

                USER_DATA_DIR="/tmp/robot-$(uuidgen | tr '[:upper:]' '[:lower:]')-$(date +%s)"
                export USER_DATA_DIR
                echo "${USER_DATA_DIR}" > .userdata_dir

                mkdir -p "${USER_DATA_DIR}/Default" && chmod -R 777 "${USER_DATA_DIR}"

                echo "Zawartość USER_DATA_DIR:"
                ls -la "${USER_DATA_DIR}"

                . venv/bin/activate
                robot --outputdir robot_reports \
                --variable HEADLESS:true \
                --variable USER_DATA_DIR:"${USER_DATA_DIR}" \
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

        stage('Send email') {
            steps {
                mail to: 'emil-pelak@outlook.com',
                     subject: "Amazon UI Tests - Build ${env.BUILD_NUMBER}",
                     body: "Wyniki testów dostępne w Jenkinsie: ${env.BUILD_URL}"
            }
        }
    }

    post {
        always {
            script {
                def dir = fileExists('.userdata_dir') ? readFile('.userdata_dir').trim() : ''
                if (dir) {
                    echo "🧹 Usuwanie USER_DATA_DIR: ${dir}"
                    sh "rm -rf ${dir} || true"
                } else {
                    echo "USER_DATA_DIR nie został odnaleziony – pomijam czyszczenie"
                }
            }
        }
    }
}
