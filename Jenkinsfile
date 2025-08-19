pipeline {
  agent any

  environment {
    ROBOT_DIR      = "robot_reports"
    PY_ENV         = "venv"
    HEADLESS       = "true"
    EMAIL_FROM     = "emil-pelak@wp.pl"
    EMAIL_TO       = "emil-pelak@outlook.com"
    MAX_ATTACH_MB  = "7"
  }

  options {
    timestamps()
    ansiColor('xterm')
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
          python3 -m venv ${PY_ENV} || true
          . ${PY_ENV}/bin/activate
          pip install --upgrade pip wheel
          pip install -r requirements.txt
        '''
      }
    }

    stage('Run tests') {
      steps {
        // do not abort whole pipeline on test failures
        catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
          sh '''
            set -e
            echo "Cleaning old /tmp/robot-* profiles"
            find /tmp -maxdepth 1 -user "$(whoami)" -type d -name "robot-*" -exec rm -rf {} + || true

            . ${PY_ENV}/bin/activate
            mkdir -p ${ROBOT_DIR}

            robot \
              --outputdir ${ROBOT_DIR} \
              --reporttitle "Wikipedia - test report" \
              --logtitle    "Wikipedia - test log"  \
              --variable HEADLESS:${HEADLESS} \
              tests/
          '''
        }
      }
    }

    stage('Make snapshot & package') {
      when { expression { fileExists("${ROBOT_DIR}/report.html") } }
      steps {
        sh '''
          set -e
          HTML="$(readlink -f ${ROBOT_DIR}/report.html)"
          SNAP="${ROBOT_DIR}/report_snapshot.png"

          okshot=0
          for B in google-chrome google-chrome-stable chromium chromium-browser; do
            if command -v "$B" >/dev/null 2>&1; then
              "$B" --headless=new --disable-gpu --no-sandbox \
                  --window-size=1920,1200 \
                  --screenshot="${SNAP}" "file://${HTML}" && okshot=1 && break
            fi
          done
          if [ "$okshot" -eq 1 ]; then
            echo "Report snapshot created at ${SNAP}"
          else
            echo "WARNING: Could not create report snapshot (no Chrome/Chromium)."
          fi

          ( cd ${ROBOT_DIR} && zip -9qr ../${ROBOT_DIR}.zip . )
        '''
      }
    }

    stage('Publish report') {
      when { expression { fileExists("${ROBOT_DIR}/report.html") } }
      steps {
        script {
          try {
            publishHTML(target: [
              allowMissing: false,
              keepAll: true,
              reportDir: "${ROBOT_DIR}",
              reportFiles: "report.html",
              reportName: "Robot Report"
            ])
          } catch (e) {
            echo "WARN publishHTML: ${e}"
          }
        }
        archiveArtifacts artifacts: "${ROBOT_DIR}/**, ${ROBOT_DIR}.zip", fingerprint: true
      }
    }
  }

  post {
    always {
      script {
        // links
        def reportUrl  = "${env.BUILD_URL}Robot_20Report/"
        def consoleUrl = "${env.BUILD_URL}console"
        def zipUrl     = "${env.BUILD_URL}artifact/${ROBOT_DIR}.zip"

        // git metadata
        def branch = sh(
          script: 'git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev/main',
          returnStdout: true
        ).trim().replaceFirst(/^origin\\//,'')
        def shortSha = sh(script: 'git rev-parse --short HEAD 2>/dev/null || echo ???????', returnStdout: true).trim()
        def subject  = sh(script: 'git log -1 --pretty=%s 2>/dev/null || echo "-"', returnStdout: true).trim()
        def author   = sh(script: 'git log -1 --pretty="%an <%ae>" 2>/dev/null || echo "-"', returnStdout: true).trim()

        // make snapshot if stage was skipped for any reason
        def shotPath = "${env.WORKSPACE}/${ROBOT_DIR}/report_snapshot.png"
        if (!fileExists(shotPath) && fileExists("${env.WORKSPACE}/${ROBOT_DIR}/report.html")) {
          sh '''
            set -e
            HTML="$(readlink -f ${ROBOT_DIR}/report.html)"
            SNAP="${ROBOT_DIR}/report_snapshot.png"
            for B in google-chrome google-chrome-stable chromium chromium-browser; do
              if command -v "$B" >/dev/null 2>&1; then
                "$B" --headless=new --disable-gpu --no-sandbox --window-size=1920,1200 \
                    --screenshot="${SNAP}" "file://${HTML}" && break
              fi
            done
          '''
        }

        // KPI from output.xml using Python (no ScriptApproval needed)
        sh '''
          set -e
          OUT="${ROBOT_DIR}/output.xml"
