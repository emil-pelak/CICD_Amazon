pipeline {
  agent { label 'built-in' }

  options {
    disableConcurrentBuilds()
    timestamps()
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
        emailext(
          subject: "Wynik testów: ${currentBuild.currentResult}",
          body: """
          Build: ${env.BUILD_URL}
          Raport: ${env.BUILD_URL}artifact/robot_reports/report.html
          Log: ${env.BUILD_URL}artifact/robot_reports/log.html
          """,
          to: 'emil-pelak@outlook.com',
          from: 'emil-pelak@wp.pl'
        )
      }
      echo "Pipeline finished: ${currentBuild.currentResult}"
    }
  }
}
