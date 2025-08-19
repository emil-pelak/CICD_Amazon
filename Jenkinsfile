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
        sh '''
          set -e
          echo "🧹 Cleaning old /tmp/robot-* profiles"
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

  post {
    always {
      // --- Snapshot & ZIP (rób nawet przy FAIL) ---
      sh '''
        set -e
        HTML="$(readlink -f ${ROBOT_DIR}/report.html || true)"
        SNAP="${ROBOT_DIR}/report_snapshot.png"

        if [ -n "$HTML" ] && [ -f "$HTML" ]; then
          okshot=0
          for B in google-chrome google-chrome-stable chromium chromium-browser; do
            if command -v "$B" >/dev/null 2>&1; then
              "$B" --headless=new --disable-gpu --no-sandbox \
                  --window-size=1600,1000 \
                  --screenshot="${SNAP}" "file://${HTML}" && okshot=1 && break
            fi
          done
          if [ "$okshot" -eq 1 ]; then
            echo "Report snapshot created at ${SNAP}"
          else
            echo "WARN: could not create snapshot (no Chrome/Chromium found)."
          fi
        else
          echo "WARN: ${ROBOT_DIR}/report.html not found – skipping snapshot."
        fi

        ( cd ${ROBOT_DIR} && zip -9qr ../${ROBOT_DIR}.zip . ) || true
      '''

      publishHTML(target: [
        allowMissing: true,
        keepAll: true,
        reportDir: "${ROBOT_DIR}",
        reportFiles: "report.html",
        reportName: "Robot Report"
      ])
      archiveArtifacts artifacts: "${ROBOT_DIR}/**, ${ROBOT_DIR}.zip", fingerprint: true

      // --- E-mail ---
      script {
        def reportUrl  = "${env.BUILD_URL}Robot_20Report/"
        def consoleUrl = "${env.BUILD_URL}console"
        def zipUrl     = "${env.BUILD_URL}artifact/${ROBOT_DIR}.zip"

        def branch = sh(
          script: 'git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev/main',
          returnStdout: true
        ).trim().replaceFirst(/^origin\\//,'')
        def shortSha = sh(script: 'git rev-parse --short HEAD 2>/dev/null || echo ???????', returnStdout: true).trim()
        def commitTitle = sh(script: 'git log -1 --pretty=%s 2>/dev/null || echo "-"', returnStdout: true).trim()
        def author      = sh(script: 'git log -1 --pretty="%an" 2>/dev/null || echo "-"', returnStdout: true).trim()

        def imgTag = ''
        def shot   = "${env.WORKSPACE}/${ROBOT_DIR}/report_snapshot.png"
        if (fileExists(shot)) {
          def b64 = sh(script: "base64 -w0 '${shot}'", returnStdout: true).trim()
          imgTag = '<img class="thumb" src="data:image/png;base64,' + b64 + '" alt="Robot report snapshot"/>'
        } else {
          imgTag = '<div class="thumb" style="border:1px dashed #e5e7eb;border-radius:10px;padding:14px;color:#6b7280">Snapshot unavailable</div>'
        }

        String buildStatus = currentBuild.currentResult ?: 'SUCCESS'
        String statusColor = (buildStatus == 'SUCCESS') ? '#16a34a' : '#dc2626'
        String statusIcon  = (buildStatus == 'SUCCESS') ? '✅' : '❌'
        String subj        = "[${buildStatus}] ${env.JOB_NAME} #${env.BUILD_NUMBER} - Wikipedia - test report"

        String body = """
<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>${subj}</title>
<style>
  body { font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif; background:#f8fafc; padding:20px }
  .card { background:#fff; border:1px solid #e5e7eb; border-radius:14px; max-width:900px; margin:auto; overflow:hidden; box-shadow:0 1px 3px rgba(0,0,0,.06) }
  .status { background:${statusColor}; color:#fff; padding:16px 20px; font-size:18px; font-weight:700 }
  .sub { color:#e5e7eb; font-weight:500 }
  .section { padding:0 20px 16px 20px }
  .h { display:flex; align-items:center; gap:8px; font-weight:800; margin:8px 0 10px 0; color:#111827 }
  .btns { padding:0 20px 20px 20px }
  a.btn { display:inline-block; margin-right:10px; margin-top:10px; padding:10px 14px; border-radius:10px; text-decoration:none; color:#fff }
  a.primary   { background:#111827 }
  a.secondary { background:#374151 }
  a.zip       { background:#0ea5e9 }
  img.thumb { width:100%; max-width:880px; border:1px solid #eef2f7; border-radius:10px; display:block; }

  /* Commit meta */
  .meta { display:grid; grid-template-columns: 1fr 1fr; gap:12px }
  .box  { border:1px solid #eef2f7; border-radius:12px; padding:12px }
  .row  { margin:6px 0; display:flex; align-items:center; gap:8px; flex-wrap:wrap }
  .label{ color:#6b7280; font-size:12px }
  .chip { display:inline-flex; align-items:center; gap:6px; padding:4px 10px; border-radius:999px; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; border:1px solid #e5e7eb; background:#f9fafb }
  .chip.branch { background:#eef2ff; border-color:#e0e7ff; color:#1e3a8a }
  .chip.sha    { background:#ecfeff; border-color:#cffafe; color:#155e75 }

  .ic { width:18px; height:18px; vertical-align:middle }
  .title { font-weight:700; color:#111827 }
  .author { color:#111827 }
</style>
</head>
<body>
  <div class="card">
    <div class="status">${statusIcon} ${buildStatus} <span class="sub">• ${env.JOB_NAME}</span> <span class="sub">• Build #${env.BUILD_NUMBER}</span></div>

    <div class="section">
      <div class="h">
        <!-- Git logo (inline SVG) -->
        <svg class="ic" viewBox="0 0 24 24" aria-hidden="true">
          <rect x="5" y="5" width="14" height="14" rx="3" ry="3" fill="#f1502f" transform="rotate(45 12 12)"></rect>
          <circle cx="10" cy="10" r="1.8" fill="white"></circle>
          <circle cx="14" cy="14" r="1.8" fill="white"></circle>
          <circle cx="14" cy="10" r="1.8" fill="white"></circle>
          <path d="M10 10 L14 14 M10 10 L14 10" stroke="white" stroke-width="1.6" fill="none"></path>
        </svg>
        <span>Commit</span>
      </div>

      <div class="meta">
        <div class="box">
          <div class="row">
            <span class="label">
              <!-- Branch icon -->
              <svg class="ic" viewBox="0 0 24 24" aria-hidden="true">
                <circle cx="6" cy="6" r="2.2" fill="#1e3a8a"></circle>
                <circle cx="18" cy="6" r="2.2" fill="#1e3a8a"></circle>
                <circle cx="18" cy="18" r="2.2" fill="#1e3a8a"></circle>
                <path d="M6 8 v6 a4 4 0 0 0 4 4 h6" stroke="#1e3a8a" stroke-width="2" fill="none"></path>
              </svg>
              Branch
            </span>
            <span class="chip branch">${branch}</span>
          </div>

          <div class="row">
            <span class="label">
              <!-- Hash icon -->
              <svg class="ic" viewBox="0 0 24 24" aria-hidden="true">
                <path d="M9 3 L7 21 M17 3 L15 21 M4 9 H20 M3 15 H19" stroke="#155e75" stroke-width="2" fill="none" stroke-linecap="round"></path>
              </svg>
              SHA
            </span>
            <span class="chip sha">${shortSha}</span>
          </div>
        </div>

        <div class="box">
          <div class="row"><span class="label">Commit title:</span> <span class="title">${commitTitle}</span></div>
          <div class="row"><span class="label">Author:</span> <span class="author">${author}</span></div>
        </div>
      </div>
    </div>

    <div class="btns">
      <a class="btn primary"   href="${reportUrl}"  target="_blank">🔎 Open "Wikipedia - test report"</a>
      <a class="btn secondary" href="${consoleUrl}" target="_blank">🖥 Console Output</a>
      <a class="btn zip"       href="${zipUrl}"     target="_blank">📦 Download results (ZIP)</a>
    </div>

    <div class="section">${imgTag}</div>
  </div>
</body>
</html>
"""

        // Załącz ZIP jeśli nie za duży
        def zipPath   = "${ROBOT_DIR}.zip"
        def attachZip = false
        if (fileExists(zipPath)) {
          try {
            long bytes   = (sh(script: "stat -c%s '${zipPath}' || echo 0", returnStdout: true).trim() as long)
            long maxByte = (env.MAX_ATTACH_MB as Integer) * 1024L * 1024L
            attachZip = (bytes > 0 && bytes <= maxByte)
            echo "ZIP size: ${bytes} bytes (attach <= ${maxByte}) -> attachZip=${attachZip}"
          } catch (ignored) {}
        }

        if (attachZip) {
          emailext(subject: subj, from: env.EMAIL_FROM, to: env.EMAIL_TO,
                   body: body, mimeType: 'text/html', attachmentsPattern: zipPath)
        } else {
          emailext(subject: subj, from: env.EMAIL_FROM, to: env.EMAIL_TO,
                   body: body, mimeType: 'text/html')
        }
      }
    }
  }
}
