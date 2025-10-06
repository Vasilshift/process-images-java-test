pipeline {
  agent any
  options { timestamps() }

  environment {
    // ---- DOKS / DOCR ----
    KUBECONFIG   = '${WORKSPACE}/.kube/config'
    KUBE_CONTEXT = "do-nyc1-k8s-tenderizz-delivery"   // change if your context differs
    NAMESPACE    = "apps"

    REGISTRY_HOST = "registry.digitalocean.com"
    REGISTRY_NAME = "upload-grocery-data-app"         // DOCR registry name (not the repo)
    APP_NAME      = "process-images-java-test"         // Deployment & container name
    IMAGE_NAME    = "${REGISTRY_HOST}/${REGISTRY_NAME}/${APP_NAME}"

    // ---- Манифесты ----
    // Основная папка с yaml-файлами (без kustomize)
    MANIFEST_DIR = "k8s/do"
    // Резервная папка (если основной нет)
    MANIFEST_DIR_FALLBACK = "k8s"
    // Можно указать конкретный файл, если нужно
    FALLBACK_MANIFEST = ""   // оставить пустым, если применяем целую папку
  }

  stages {
    stage("Checkout") {
      steps { checkout scm }
    }

    stage("Load kubeconfig") {
      steps {
        withCredentials([file(credentialsId: "do-kubeconfig", variable: "KCFG")]) {
          sh '''
            set -euxo pipefail
            mkdir -p "$(dirname "$KUBECONFIG")"
            cp "$KCFG" "$KUBECONFIG"
            chmod 600 "$KUBECONFIG"
            kubectl --kubeconfig="$KUBECONFIG" config use-context "$KUBE_CONTEXT"
            kubectl --kubeconfig="$KUBECONFIG" get nodes
          '''
        }
      }
    }

    stage("Compute tag") {
      steps {
        script {
          env.IMAGE_TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          echo "Image tag = ${env.IMAGE_TAG}"
        }
      }
    }

    stage("Build & Push Image (DOCR)") {
      steps {
        withCredentials([usernamePassword(credentialsId: "docker-registry",
                                          usernameVariable: "REG_USERNAME",
                                          passwordVariable: "REG_PASSWORD")]) {
          sh '''
            set -euxo pipefail
            export DOCKER_CONFIG="$(mktemp -d)"
            docker logout ${REGISTRY_HOST} || true
            printf %s "$REG_PASSWORD" | docker login ${REGISTRY_HOST} -u "$REG_USERNAME" --password-stdin

            docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
            docker push  ${IMAGE_NAME}:${IMAGE_TAG}
          '''
        }
      }
    }

    stage("Prepare namespace & imagePullSecret") {
      steps {
        withCredentials([usernamePassword(credentialsId: "docker-registry",
                                          usernameVariable: "REG_USERNAME",
                                          passwordVariable: "REG_PASSWORD")]) {
          sh '''
            set -euxo pipefail
            # ensure namespace exists
            kubectl --kubeconfig="$KUBECONFIG" get ns ${NAMESPACE} >/dev/null 2>&1 || \
              kubectl --kubeconfig="$KUBECONFIG" create ns ${NAMESPACE}

            # ensure pull secret used by Deployment: imagePullSecrets: docker-registry
            kubectl --kubeconfig="$KUBECONFIG" -n ${NAMESPACE} create secret docker-registry docker-registry \
              --docker-server=${REGISTRY_HOST} \
              --docker-username="$REG_USERNAME" \
              --docker-password="$REG_PASSWORD" \
              --docker-email="ci@local" \
              --dry-run=client -o yaml | kubectl --kubeconfig="$KUBECONFIG" apply -f -
          '''
        }
      }
    }



    stage("Apply manifests & set image") {
      steps {
        sh '''
          set -euxo pipefail

          if [ -d "${MANIFEST_DIR}" ]; then
            # применяем ВСЕ yaml в каталоге (без kustomize)
            kubectl --kubeconfig="$KUBECONFIG" -n ${NAMESPACE} apply -f "${MANIFEST_DIR}" --recursive
          elif [ -d "${MANIFEST_DIR_FALLBACK}" ]; then
            kubectl --kubeconfig="$KUBECONFIG" -n ${NAMESPACE} apply -f "${MANIFEST_DIR_FALLBACK}" --recursive
          elif [ -n "${FALLBACK_MANIFEST}" ] && [ -f "${FALLBACK_MANIFEST}" ]; then
            kubectl --kubeconfig="$KUBECONFIG" -n ${NAMESPACE} apply -f "${FALLBACK_MANIFEST}"
          else
            echo "ERROR: no manifests found (MANIFEST_DIR='${MANIFEST_DIR}', MANIFEST_DIR_FALLBACK='${MANIFEST_DIR_FALLBACK}', or FALLBACK_MANIFEST='${FALLBACK_MANIFEST}')." >&2
            exit 1
          fi

          # Обновляем образ в нужном Deployment/контейнере
          kubectl --kubeconfig="$KUBECONFIG" -n ${NAMESPACE} set image deploy/${APP_NAME} \
            ${APP_NAME}=${IMAGE_NAME}:${IMAGE_TAG}
        '''
      }
    }

    stage("Rollout & verify") {
      steps {
        sh '''
          set -euxo pipefail
          kubectl --kubeconfig="$KUBECONFIG" -n ${NAMESPACE} rollout status deployment/${APP_NAME} --timeout=180s
          kubectl --kubeconfig="$KUBECONFIG" -n ${NAMESPACE} get pods -l app.kubernetes.io/name=${APP_NAME} -o wide
        '''
      }
    }
  }

  post {
    failure {
      sh '''
        set +e
        echo "---- DEBUG DUMP ----"
        kubectl --kubeconfig="$KUBECONFIG" config current-context || true
        kubectl --kubeconfig="$KUBECONFIG" -n ${NAMESPACE} describe deployment/${APP_NAME} || true
        kubectl --kubeconfig="$KUBECONFIG" -n ${NAMESPACE} get rs,pods -l app.kubernetes.io/name=${APP_NAME} -o wide || true
        kubectl --kubeconfig="$KUBECONFIG" -n ${NAMESPACE} get events --sort-by=.lastTimestamp | tail -n 200 || true
      '''
    }
  }
}
