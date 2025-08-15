pipeline {
  agent { label 'built-in' }

  options {
    disableConcurrentBuilds()
    timestamps()
  }

  environment {
    HEADLESS = 'true' // na Jenkinsie headless
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

          # NIE przerywamy joba - chcemy mieć raport
          robot --outputdir robot_reports \
                --reporttitle "Wikipedia – Raport z testów" \
                --logtitle "Wikipedia – Log z testów" \
                --variable HEADLESS:$HEADLESS \
                tests/ || true
        '''
      }
    }

    stage('Publish report') {
      steps {
        // Kompaktowy pakiet wyników
        sh '''
          cd robot_reports
          # jeśli screeny są duże, możesz dodać --junk-paths lub odfiltrować *.png by ograniczyć wagę
          zip -r ../robot_reports.zip . >/dev/null 2>&1 || true
        '''

        publishHTML([
          allowMissing: true,
          alwaysLinkToLastBuild: true,
          keepAll: true,
          reportDir: 'robot_reports',
          reportFiles: 'report.html',
          reportName: 'Robot Report'
        ])
        archiveArtifacts artifacts: 'robot_reports/**, robot_reports.zip', fingerprint: true, allowEmptyArchive: true
      }
    }
  }

  post {
    always {
      script {
        // Linki do artefaktów (działają po ustawieniu CSP w Jenkinsie – patrz sekcja poniżej)
        def reportUrl = "${env.BUILD_URL}artifact/robot_reports/report.html"
        def logUrl    = "${env.BUILD_URL}artifact/robot_reports/log.html"
        def zipUrl    = "${env.BUILD_URL}artifact/robot_reports.zip"
        def console   = "${env.BUILD_URL}console"

        // Kolorystyka maila wg wyniku
        def ok = (currentBuild.currentResult ?: 'SUCCESS') == 'SUCCESS'
        def headerColor = ok ? "#22c55e" : "#ef4444"
        def emoji = ok ? "✅" : "❌"
        def title = ok ? "TESTY ZALICZONE" : "TESTY NIEPRZESZŁY"

        // Mail potrafi czasem „zgubić się” – damy 2 próby
        retry(2) {
          emailext(
            to:   'emil-pelak@outlook.com',
            from: 'emil-pelak@wp.pl',
            subject: "[${currentBuild.currentResult}] ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            mimeType: 'text/html',
            // UWAGA: brak HTML-owych załączników – tylko linki + ZIP.
            attachmentsPattern: 'robot_reports.zip',
            body: """
            <div style="font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif;line-height:1.5">
              <div style="background:${headerColor};color:white;padding:12px 16px;border-radius:8px;margin-bottom:12px;">
                <strong style="font-size:16px">${emoji} ${title}</strong>
                <div style="opacity:.9">Job: ${env.JOB_NAME} • Build #${env.BUILD_NUMBER}</div>
              </div>

              <ul>
                <li><a href="${reportUrl}">📄 Robot Report (HTML)</a></li>
                <li><a href="${logUrl}">📜 Robot Log (HTML)</a></li>
                <li><a href="${zipUrl}">🗜️ Pełny pakiet wyników (ZIP)</a></li>
                <li><a href="${console}">🖥️ Console Output</a></li>
              </ul>

              <p style="margin-top:12px">
                Gałąź: <code>${env.GIT_BRANCH ?: 'n/d'}</code><br/>
                Commit: <code>${env.GIT_COMMIT ?: 'n/d'}</code>
              </p>
            </div>
            """
          )
        }
      }

      echo "Pipeline finished: ${currentBuild.currentResult}"
    }
  }
}
