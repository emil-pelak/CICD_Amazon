pipeline {
  agent { label 'built-in' }

  options {
    disableConcurrentBuilds()
    timestamps()
  }

  parameters {
    string(name: 'EMAIL_TO',   defaultValue: 'twoj-outlook@example.com', description: 'Adres odbiorcy')
    string(name: 'EMAIL_FROM', defaultValue: 'twoj-wp@example.com', description: 'Adres nadawcy (musi być zgodny z konfiguracją SMTP)')
  }

  environment {
    HEADLESS = 'true' // tylko headless na Jenkinsie
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Install dependencies') {
      steps {
        sh '''
          set -e
          python3 -m venv venv || true
          . venv/bin/activate
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
          find /tmp -maxdepth 1 -user $(whoami) -type d -name 'robot-*' -exec rm -rf {} + || true

          . venv/bin/activate
          mkdir -p robot_reports
          echo "HEADLESS=$HEADLESS"
          # NIE przerywaj całego joba – chcemy opublikować raport nawet przy FAIL
          robot --outputdir robot_reports \
                --variable HEADLESS:$HEADLESS \
                tests/ || true
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
        archiveArtifacts artifacts: 'robot_reports/**', fingerprint: true, allowEmptyArchive: true
      }
    }
  }

  post {
    always {
      script {
        // Linki do raportów
        def reportUrl = "${env.BUILD_URL}artifact/robot_reports/report.html"
        def logUrl    = "${env.BUILD_URL}artifact/robot_reports/log.html"
        def console   = "${env.BUILD_URL}console"

        emailext(
          to: params.EMAIL_TO,
          from: params.EMAIL_FROM,
          subject: "[${currentBuild.currentResult}] ${env.JOB_NAME} #${env.BUILD_NUMBER}",
          mimeType: 'text/html',
          body: """
            <h3>Wynik: ${currentBuild.currentResult}</h3>
            <p><b>${env.JOB_NAME}</b> #${env.BUILD_NUMBER}</p>
            <ul>
              <li><a href="${reportUrl}">Robot Report</a></li>
              <li><a href="${logUrl}">Robot Log</a></li>
              <li><a href="${console}">Console Output</a></li>
            </ul>
          """,
          attachmentsPattern: 'robot_reports/report.html, robot_reports/log.html'
        )
      }
      echo "Pipeline finished: ${currentBuild.currentResult}"
    }
  }
}
