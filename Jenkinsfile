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
                    SER_DATA_DIR=""
                    export USER_DATA_DIR
                    echo "${USER_DATA_DIR}" > .userdata_dir

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
