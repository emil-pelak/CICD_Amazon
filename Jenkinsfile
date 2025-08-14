pipeline {
  agent { label 'built-in' }

  options {
    disableConcurrentBuilds()
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '25'))
  }

  environment {
    # HEADLESS ustawia matrix niżej; tu default dla lokalnego uruchamiania bez matrix
    HEADLESS = 'true'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Python venv & deps') {
      steps {
        sh '''
          set -e
          if [ ! -d venv ]; then python3 -m venv venv; fi
          . venv/bin/activate
          pip install --upgrade pip wheel
          pip install -r requirements.txt
        '''
      }
    }

    stage('Run tests (matrix headless/gui)') {
      matrix {
        axes {
          axis { name 'MODE'; values 'headless', 'gui' }
        }
        stages {
          stage('Execute') {
            steps {
              sh '''
                set -e
                . venv/bin/activate
                mkdir -p robot_reports/${MODE}
                if [ "${MODE}" = "gui" ]; then export HEADLESS=false; else export HEADLESS=true; fi

                echo "Running in MODE=${MODE}, HEADLESS=${HEADLESS}, SEARCH_TERM=${SEARCH_TERM:-Robot Framework}"
                robot --outputdir robot_reports/${MODE} \
                      --reporttitle "Wikipedia ${MODE} report" \
                      --logtitle "Wikipedia ${MODE} log" \
                      --variable HEADLESS:$HEADLESS \
                      --variable SEARCH_TERM:"${SEARCH_TERM:-Robot Framework}" \
                      tests/ || true
              '''
            }
          }
        }
        post {
          always {
            // Publikuj raporty Robot dla każdego wariantu
            robot outputPath: "robot_reports/${MODE}",
                  outputFileName: 'output.xml',
                  reportFileName: 'report.html',
                  logFileName: 'log.html'
            archiveArtifacts artifacts: "robot_reports/${MODE}/**", fingerprint: true, allowEmptyArchive: true
          }
        }
      }
    }
  }

  post {
    always {
      // Trend testów (opcjonalnie)
      junit allowEmptyResults: true, testResults: 'robot_reports/**/output.xml'
      echo "Pipeline finished: ${currentBuild.currentResult}"
    }
  }
}
