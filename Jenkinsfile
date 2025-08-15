pipeline {
  agent { label 'built-in' }

  options {
    disableConcurrentBuilds()
    timestamps()
  }

  environment {
    HEADLESS = 'true' // na Jenkinsie tylko headless
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

          # uruchomienie Robot Framework z czytelnymi tytułami
          robot \
            --outputdir robot_reports \
            --reporttitle "Wikipedia - test report" \
            --logtitle    "Wikipedia - test log" \
            --variable HEADLESS:$HEADLESS \
            tests/
        '''
      }
    }

    stage('Publish report') {
      steps {
        // spakuj cały katalog wyników, żeby był do pobrania z Jenkins /artifact
        sh '''
          cd robot_reports
          zip -r ../robot_reports.zip .
        '''

        publishHTML([
          allowMissing: true,
          alwaysLinkToLastBuild: true,
          keepAll: true,
          reportDir: 'robot_reports',
          reportFiles: 'report.html',
          reportName: 'Robot Report'
        ])

        archiveArtifacts artifacts: 'robot_reports/**, robot_reports.zip', fingerprint: true, allowEmptyArchive: false
      }
    }
  }

  post {
    always {
      script {
        // Przygotuj ładne linki (wszystkie działają w Chrome/Firefox)
        // Kluczowe: link do HTML Publisher, nie do /artifact/… (omija CSP)
        def robotReportUrl = "${env.BUILD_URL}Robot_20Report/"
        def consoleUrl     = "${env.BUILD_URL}console"
        def artifactZipUrl = "${env.BUILD_URL}artifact/robot_reports.zip"

        // Info o gałęzi/commicie
        def gitBranch = env.GIT_BRANCH ?: 'HEAD'
        def gitSha    = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
        def gitMsg    = sh(script: "git log -1 --pretty=%s", returnStdout: true).trim()
        def author    = sh(script: "git log -1 --pretty='%an <%ae>'", returnStdout: true).trim()

        // Krótki, czytelny HTML w treści maila – tylko linki, bez załączników
        def subj = "[${currentBuild.currentResult}] ${env.JOB_NAME} #${env.BUILD_NUMBER} – Wikipedia - test report"
        def body = """
        <div style="font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif">
          <div style="background:#22c55e;color:#fff;padding:14px 16px;border-radius:10px;margin-bottom:16px;">
            <strong>✅ TESTY ${currentBuild.currentResult == 'SUCCESS' ? 'ZALICZONE' : 'ZAKOŃCZONE'}</strong>
            • <span style="opacity:.9">${env.JOB_NAME}</span> • <strong>Build #${env.BUILD_NUMBER}</strong>
          </div>

          <ul style="line-height:1.8;margin:0 0 14px 0;padding-left:18px;">
            <li>🔎 <a href="${robotReportUrl}" target="_blank">Otwórz „Wikipedia - test report”</a></li>
            <li>🧾 <a href="${consoleUrl}" target="_blank">Console Output</a></li>
            <li>📦 <a href="${artifactZipUrl}" target="_blank">Pełny pakiet wyników (ZIP)</a></li>
          </ul>

          <div style="margin-top:16px;padding:12px 14px;border:1px solid #e5e7eb;border-radius:8px;">
            <div style="font-weight:600;margin-bottom:8px;">Commit</div>
            <div><b>Branch:</b> ${gitBranch}</div>
            <div><b>Commit:</b> <code>${gitSha}</code> – ${gitMsg}</div>
            <div><b>Author:</b> ${author}</div>
          </div>

          <p style="color:#6b7280;margin-top:14px">
            Uwaga: jeśli Chrome blokuje bezpośrednie HTML-e z artefaktów, używaj linku „Robot Report” powyżej (jest zgodny z CSP).
          </p>
        </div>
        """

        emailext(
          subject: subj,
          from:    env.EMAIL_FROM,      // ustawione globalnie: emil-pelak@wp.pl
          to:      env.EMAIL_TO,        // ustaw: emil-pelak@outlook.com
          body:    body,
          mimeType: 'text/html'
          // Brak attachmentsPattern -> wysyłamy tylko linki
        )

        echo "Pipeline finished: ${currentBuild.currentResult}"
      }
    }
  }
}
