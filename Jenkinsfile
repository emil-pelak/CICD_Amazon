pipeline {
    agent any

    environment {
        ROBOT_DIR = "robot_reports"
        PYTHON_ENV = "venv"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout([$class: 'GitSCM',
                    branches: [[name: "*/dev/main"]],
                    userRemoteConfigs: [[
                        url: "git@github.com:emil-pelak/CICD_Wikipedia.git",
                        credentialsId: "local_github-ssh"
                    ]]
                ])
            }
        }

        stage('Install dependencies') {
            steps {
                sh '''
                    set -e
                    python3 -m venv ${PYTHON_ENV}
                    . ${PYTHON_ENV}/bin/activate
                    pip install --upgrade pip wheel
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Run tests') {
            steps {
                sh '''
                    set -e
                    echo "🧹 Czyszczenie starych profili /tmp/robot-*"
                    find /tmp -maxdepth 1 -user jenkins -type d -name "robot-*" -exec rm -rf {} +
                    . ${PYTHON_ENV}/bin/activate
                    mkdir -p ${ROBOT_DIR}
                    robot \
                        --outputdir ${ROBOT_DIR} \
                        --reporttitle "Wikipedia - test report" \
                        --logtitle "Wikipedia - test log" \
                        --variable HEADLESS:true \
                        tests/
                '''
            }
        }

        stage('Publish report') {
            steps {
                sh '''
                    cd ${ROBOT_DIR}
                    zip -r ../${ROBOT_DIR}.zip .
                '''
                publishHTML(target: [
                    allowMissing: false,
                    keepAll: true,
                    reportDir: "${ROBOT_DIR}",
                    reportFiles: 'report.html',
                    reportName: 'Robot Report'
                ])
                archiveArtifacts artifacts: "${ROBOT_DIR}/**", fingerprint: true
                archiveArtifacts artifacts: "${ROBOT_DIR}.zip", fingerprint: true
            }
        }
    }

    post {
        always {
            script {
                def gitCommit   = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                def gitMessage  = sh(returnStdout: true, script: 'git log -1 --pretty=%s').trim()
                def gitAuthor   = sh(returnStdout: true, script: 'git log -1 --pretty="%an <%ae>"').trim()

                def buildStatus = currentBuild.result ?: 'SUCCESS'
                def reportUrl   = "${env.BUILD_URL}Robot_20Report/"
                def logUrl      = "${env.BUILD_URL}artifact/${ROBOT_DIR}/log.html"
                def zipUrl      = "${env.BUILD_URL}artifact/${ROBOT_DIR}.zip"
                def consoleUrl  = "${env.BUILD_URL}console"

                def subj = "[${buildStatus}] CICD_Wikipedia #${env.BUILD_NUMBER} – Wikipedia - test report"

                def body = """
                    <h2 style="color:${buildStatus == 'SUCCESS' ? 'green' : 'red'};">
                        ${buildStatus == 'SUCCESS' ? '✅ TESTY ZALICZONE' : '❌ TESTY NIEUDANE'}
                        • CICD_Wikipedia • Build #${env.BUILD_NUMBER}
                    </h2>
                    <p>
                        <strong>Commit:</strong> ${gitCommit} – ${gitMessage}<br>
                        <strong>Author:</strong> ${gitAuthor}
                    </p>
                    <ul>
                        <li><a href="${reportUrl}">📄 Wikipedia - test report</a></li>
                        <li><a href="${logUrl}">📜 Log</a></li>
                        <li><a href="${zipUrl}">📦 Pełny pakiet wyników (ZIP)</a></li>
                        <li><a href="${consoleUrl}">🖥 Console Output</a></li>
                    </ul>
                """

                emailext(
                    subject: subj,
                    from: 'emil-pelak@wp.pl',
                    to: 'emil-pelak@outlook.com',
                    body: body,
                    mimeType: 'text/html'
                )
            }
        }
    }
}
