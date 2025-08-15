pipeline {
  agent any

  environment {
    ROBOT_DIR  = "robot_reports"
    PY_ENV     = "venv"
    HEADLESS   = "true"                   // run headless on Jenkins
    EMAIL_FROM = "emil-pelak@wp.pl"
    EMAIL_TO   = "emil-pelak@outlook.com"
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
          cd ${ROBOT_DIR}
          zip -qr ../${ROBOT_DIR}.zip .
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
        // --- Derive links (Publisher view avoids CSP issues) ---
        def reportUrl   = "${env.BUILD_URL}Robot_20Report/"
        def consoleUrl  = "${env.BUILD_URL}console"
        def zipUrl      = "${env.BUILD_URL}artifact/${ROBOT_DIR}.zip"

        // --- Git metadata ---
        def branch   = env.GIT_BRANCH ?: 'HEAD'
        def shortSha = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        def subject  = sh(script: 'git log -1 --pretty=%s', returnStdout: true).trim()
        def author   = sh(script: 'git log -1 --pretty="%an <%ae>"', returnStdout: true).trim()

        // --- Parse Robot output.xml for KPIs ---
        def total='0', passed='0', failed='0', elapsed='--:--', startTime='-', endTime='-'
        try {
          def xml = new XmlSlurper().parse(new File("${env.WORKSPACE}/${ROBOT_DIR}/output.xml"))
          def stat = xml.statistics.total.stat[0]
          if (stat) {
            total  = (stat.@total?.toString() ?: '0')
            passed = (stat.@pass ?.toString() ?: '0')
            failed = (stat.@fail ?.toString() ?: '0')
          }
          // elapsed time is in ms on root
          def ms = (xml.@elapsedtime?.toString() ?: '')
          if (ms) {
            long s = (ms as long) / 1000L
            elapsed = String.format("%02d:%02d", (int)(s/60), (int)(s%60))
          }
          // suite timing (first top-level suite)
          def suite = xml.suite[0]
          startTime = suite?.@starttime?.toString() ?: '-'
          endTime   = suite?.@endtime ?.toString() ?: '-'
        } catch (e) {
          echo "WARN: Failed to parse output.xml: ${e}"
        }

        // --- More computed metrics ---
        def passRate = "0.0%"
        try {
          double t = (total as double)
          double p = (passed as double)
          passRate = t > 0 ? String.format("%.1f%%", (p*100.0)/t) : "0.0%"
        } catch (ignored) {}

        def buildStatus = currentBuild.result ?: 'SUCCESS'
        def statusBadgeBg = (buildStatus == 'SUCCESS') ? "#16a34a" : "#dc2626"  // green/red
        def statusIcon    = (buildStatus == 'SUCCESS') ? "✅" : "❌"

        // --- Environment section (you can expand this as needed) ---
        def nodeName = env.NODE_NAME ?: 'built-in'
        def browser  = "Chrome (headless=${env.HEADLESS})"

        // --- Email subject & body (English, polished UI) ---
        def subj = "[${buildStatus}] ${env.JOB_NAME} #${env.BUILD_NUMBER} – Wikipedia - test report"

        def body = """
<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>${subj}</title>
<style>
  body { font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif; background:#f8fafc; padding:20px }
  .card { background:#fff; border:1px solid #e5e7eb; border-radius:14px; max-width:900px; margin:auto; overflow:hidden; box-shadow:0 1px 3px rgba(0,0,0,.06) }
  .status { background:${statusBadgeBg}; color:#fff; padding:16px 20px; font-size:18px; font-weight:700 }
  .sub { color:#e5e7eb; font-weight:500 }
  .grid { display:grid; grid-template-columns: repeat(5, minmax(120px,1fr)); gap:12px; padding:16px 20px 8px 20px }
  .kpi { background:#f9fafb; border:1px solid #eef2f7; border-radius:12px; padding:12px; text-align:center }
  .kpi .label { font-size:12px; color:#6b7280; display:block }
  .kpi .val   { font-size:22px; font-weight:800; margin-top:2px }
  .section { padding:0 20px 16px 20px }
  .h { font-weight:700; margin:8px 0 10px 0; color:#111827 }
  .mono { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; background:#f3f4f6; padding:2px 6px; border-radius:6px }
  .btns { padding:0 20px 20px 20px }
  a.btn { display:inline-block; margin-right:10px; margin-top:10px; padding:10px 14px; border-radius:10px; text-decoration:none; color:#fff }
  a.primary   { background:#111827 }
  a.secondary { background:#374151 }
  a.zip       { background:#0ea5e9 }
  .meta { display:grid; grid-template-columns: 1fr 1fr; gap:12px }
  .box  { border:1px solid #eef2f7; border-radius:12px; padding:12px }
  .muted { color:#6b7280; font-size:12px }
</style>
</head>
<body>
  <div class="card">
    <div class="status">${statusIcon} ${buildStatus} <span class="sub">• ${env.JOB_NAME}</span> <span class="sub">• Build #${env.BUILD_NUMBER}</span></div>

    <div class="grid">
      <div class="kpi"><span class="label">Total</span><span class="val">${total}</span></div>
      <div class="kpi"><span class="label">Passed</span><span class="val">${passed}</span></div>
      <div class="kpi"><span class="label">Failed</span><span class="val">${failed}</span></div>
      <div class="kpi"><span class="label">Pass rate</span><span class="val">${passRate}</span></div>
      <div class="kpi"><span class="label">Duration (mm:ss)</span><span class="val">${elapsed}</span></div>
    </div>

    <div class="section meta">
      <div class="box">
        <div class="h">Commit</div>
        <div><b>Branch:</b> <span class="mono">${branch}</span></div>
        <div><b>SHA:</b> <span class="mono">${shortSha}</span></div>
        <div><b>Message:</b> ${subject}</div>
        <div><b>Author:</b> ${author}</div>
      </div>
      <div class="box">
        <div class="h">Execution</div>
        <div><b>Start:</b> ${startTime}</div>
        <div><b>End:</b> ${endTime}</div>
        <div><b>Node:</b> ${nodeName}</div>
        <div><b>Browser:</b> ${browser}</div>
      </div>
    </div>

    <div class="btns">
      <a class="btn primary"   href="${reportUrl}"  target="_blank">🔎 Open “Wikipedia - test report”</a>
      <a class="btn secondary" href="${consoleUrl}" target="_blank">🖥 Console Output</a>
      <a class="btn zip"       href="${zipUrl}"     target="_blank">📦 Download results (ZIP)</a>
    </div>

    <div class="section muted">If Chrome blocks direct HTML artifacts due to CSP, use the “Robot Report” link above (publisher view).</div>
  </div>
</body>
</html>
"""

        emailext(
          subject:  subj,
          from:     env.EMAIL_FROM,
          to:       env.EMAIL_TO,
          body:     body,
          mimeType: 'text/html'
        )

        echo "Pipeline finished: ${currentBuild.currentResult}"
      }
    }
  }
}
