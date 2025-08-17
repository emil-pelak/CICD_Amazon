pipeline {
  agent any

  environment {
    ROBOT_DIR  = "robot_reports"
    PY_ENV     = "venv"
    HEADLESS   = "true"                 // run headless on Jenkins agents
    EMAIL_FROM = "emil-pelak@wp.pl"
    EMAIL_TO   = "emil-pelak@outlook.com"
    // Optional: total size limit for attachments (only small HTML files).
    // Big files (screenshots) are never attached to email — they stay in ZIP.
    EMAIL_ATTACH_LIMIT_MB = "5"
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

    stage('Publish report') {
      steps {
        sh '''
          # ZIP zawiera CAŁY katalog robot_reports/ (łącznie ze screenshotami)
          cd ${ROBOT_DIR}
          zip -9qr ../${ROBOT_DIR}.zip .
        '''
        publishHTML(target: [
          allowMissing: false,
          keepAll: true,
          reportDir: "${ROBOT_DIR}",
          reportFiles: "report.html",
          reportName: "Robot Report"
        ])
        archiveArtifacts artifacts: "${ROBOT_DIR}/**, ${ROBOT_DIR}.zip", fingerprint: true
      }
    }
  }

  post {
    always {
      script {
        // --- Stable links (Publisher view avoids CSP) ---
        def reportUrl  = "${env.BUILD_URL}Robot_20Report/"
        def consoleUrl = "${env.BUILD_URL}console"
        def zipUrl     = "${env.BUILD_URL}artifact/${env.ROBOT_DIR}.zip"

        // --- Git metadata (works in detached HEAD) ---
        def branch = sh(script: 'git branch --remote --contains HEAD | head -n1 | sed -E "s#^[[:space:]]*origin/##"', returnStdout: true).trim()
        if (!branch || branch == 'HEAD') { branch = 'dev/main' }
        def shortSha = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        def subject  = sh(script: 'git log -1 --pretty=%s', returnStdout: true).trim()
        def author   = sh(script: 'git log -1 --pretty="%an <%ae>"', returnStdout: true).trim()

        // --- KPIs from Robot output.xml ---
        def total='0', passed='0', failed='0', elapsed='n/a'
        try {
          def xml = new XmlSlurper().parse(new File("${env.WORKSPACE}/${env.ROBOT_DIR}/output.xml"))
          def tests = xml.depthFirst().findAll { it.name() == 'test' }
          total  = tests.size().toString()
          passed = tests.count { it.status.@status.text() == 'PASS' }.toString()
          failed = ((total as int) - (passed as int)).toString()
          def ms = (xml.@elapsedtime?.toString() ?: '')
          if (ms) {
            long s = (ms as long) / 1000L
            elapsed = String.format("%02d:%02d", (int)(s/60), (int)(s%60))
          }
        } catch (ignored) {}

        def passRate = (total as Integer) ? String.format("%.1f%%", (passed as Double)*100D/(total as Double)) : "0.0%"
        def buildStatus = currentBuild.result ?: 'SUCCESS'
        def statusBg    = (buildStatus == 'SUCCESS') ? "#16a34a" : "#dc2626"
        def statusIcon  = (buildStatus == 'SUCCESS') ? "✅" : "❌"
        def nodeName    = env.NODE_NAME ?: 'built-in'
        def browser     = "Chrome (headless=${env.HEADLESS})"

        // --- Conditional small attachments (never screenshots) ---
        long limitBytes = ((env.EMAIL_ATTACH_LIMIT_MB ?: '5') as long) * 1024L * 1024L
        def candidates  = ["${env.ROBOT_DIR}/report.html", "${env.ROBOT_DIR}/log.html"] // small only
        def toAttach    = []
        long used       = 0L
        for (p in candidates) {
          if (fileExists(p)) {
            long sz = (sh(returnStdout: true, script: "wc -c < '${p}'").trim() as long)
            if (used + sz <= limitBytes) {
              toAttach << p
              used += sz
            }
          }
        }
        def attachNote = toAttach ? "Attached: " + toAttach.collect{ it.tokenize('/').last() }.join(', ') + " (≤ ${(limitBytes/1024/1024) as int} MB)"
                                  : "Attachments omitted due to size – use links below (ZIP contains screenshots)."

        // --- Email content (English) ---
        def subj = "[${buildStatus}] ${env.JOB_NAME} #${env.BUILD_NUMBER} – Wikipedia - test report"
        def body = """
<!doctype html><html><head><meta charset="utf-8"/>
<title>${subj}</title>
<style>
 body{font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;background:#f8fafc;padding:20px}
 .card{background:#fff;border:1px solid #e5e7eb;border-radius:14px;max-width:900px;margin:auto;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.06)}
 .status{background:${statusBg};color:#fff;padding:16px 20px;font-size:18px;font-weight:700}
 .sub{color:#e5e7eb;font-weight:500}
 .grid{display:grid;grid-template-columns:repeat(5,minmax(120px,1fr));gap:12px;padding:16px 20px 8px}
 .kpi{background:#f9fafb;border:1px solid #eef2f7;border-radius:12px;padding:12px;text-align:center}
 .kpi .label{font-size:12px;color:#6b7280;display:block}
 .kpi .val{font-size:22px;font-weight:800;margin-top:2px}
 .section{padding:0 20px 16px}
 .h{font-weight:700;margin:8px 0 10px;color:#111827}
 .mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;background:#f3f4f6;padding:2px 6px;border-radius:6px}
 .btns{padding:0 20px 20px}
 a.btn{display:inline-block;margin-right:10px;margin-top:10px;padding:10px 14px;border-radius:10px;text-decoration:none;color:#fff}
 a.primary{background:#111827} a.secondary{background:#374151} a.zip{background:#0ea5e9}
 .muted{color:#6b7280;font-size:12px}
</style></head><body>
<div class="card">
  <div class="status">${statusIcon} ${buildStatus} <span class="sub">• ${env.JOB_NAME}</span> <span class="sub">• Build #${env.BUILD_NUMBER}</span></div>

  <div class="grid">
    <div class="kpi"><span class="label">Total</span><span class="val">${total}</span></div>
    <div class="kpi"><span class="label">Passed</span><span class="val">${passed}</span></div>
    <div class="kpi"><span class="label">Failed</span><span class="val">${failed}</span></div>
    <div class="kpi"><span class="label">Pass rate</span><span class="val">${passRate}</span></div>
    <div class="kpi"><span class="label">Duration (mm:ss)</span><span class="val">${elapsed}</span></div>
  </div>

  <div class="section">
    <div class="h">Commit</div>
    <div><b>Branch:</b> <span class="mono">${branch}</span></div>
    <div><b>SHA:</b> <span class="mono">${shortSha}</span></div>
    <div><b>Message:</b> ${subject}</div>
    <div><b>Author:</b> ${author}</div>
  </div>

  <div class="section">
    <div class="h">Execution</div>
    <div><b>Node:</b> ${nodeName}</div>
    <div><b>Browser:</b> ${browser}</div>
    <div class="muted" style="margin-top:6px">${attachNote}</div>
  </div>

  <div class="btns">
    <a class="btn primary"   href="${reportUrl}"  target="_blank">🔎 Open “Wikipedia - test report”</a>
    <a class="btn secondary" href="${consoleUrl}" target="_blank">🖥 Console Output</a>
    <a class="btn zip"       href="${zipUrl}"     target="_blank">📦 Download results (ZIP)</a>
  </div>

  <div class="section muted">If Chrome blocks direct HTML artifacts due to CSP, use the “Robot Report” link above (publisher view).</div>
</div>
</body></html>
"""
        emailext(
          subject:  subj,
          from:     env.EMAIL_FROM,
          to:       env.EMAIL_TO,
          mimeType: 'text/html',
          body:     body,
          attachmentsPattern: toAttach.join(', ')
        )
        echo "Pipeline finished: ${currentBuild.currentResult}"
      }
    }
  }
}
