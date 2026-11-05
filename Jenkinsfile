pipeline {
    agent any

    // -------------------------------------------------------
    // Parameters – you can change these when you trigger the job
    // -------------------------------------------------------
    parameters {
        string(
            name: 'DOCKERHUB_USERNAME',
            defaultValue: 'Docker-Creds',
            description: 'Your Docker Hub username'
        )
        string(
            name: 'IMAGE_REPO',
            defaultValue: 'jenkins-razor-smoke',
            description: 'Name of the image repository on Docker Hub'
        )
        booleanParam(
            name: 'PUSH_LATEST',
            defaultValue: true,
            description: 'Also tag and push the image as :latest'
        )
    }

    // -------------------------------------------------------
    // Environment variables used throughout the pipeline
    // -------------------------------------------------------
    environment {
        IMAGE_NAME = "${params.DOCKERHUB_USERNAME}/${params.IMAGE_REPO}"
        IMAGE_TAG  = "${env.BUILD_NUMBER}"
        // Full image reference used in most stages
        FULL_IMAGE = "${IMAGE_NAME}:${IMAGE_TAG}"
    }

    options {
        // Keep only the last 15 builds on the Jenkins master
        buildDiscarder(logRotator(numToKeepStr: '15'))
        // Abort the job if it runs longer than 20 minutes
        timeout(time: 20, unit: 'MINUTES')
        // Add timestamps to the console output
        timestamps()
        // Do not allow concurrent builds of this job
        disableConcurrentBuilds()
    }

    stages {

        // ---------------------------------------------------
        // 1. Checkout source code
        // ---------------------------------------------------
        stage('Checkout') {
            steps {
                echo "Checking out source code..."
                checkout scm
            }
        }

        // ---------------------------------------------------
        // 2. Build the Docker image
        // ---------------------------------------------------
        stage('Build') {
            steps {
                script {
                    echo "Building image: ${FULL_IMAGE}"
                    // docker.build returns a Docker image object
                    def customImage = docker.build(FULL_IMAGE)
                    // Optionally tag as latest locally so the test stage can use it
                    if (params.PUSH_LATEST) {
                        customImage.tag('latest')
                    }
                }
            }
        }

        // ---------------------------------------------------
        // 3. Simple smoke test – start the container and hit it
        // ---------------------------------------------------
        stage('Smoke Test') {
            steps {
                script {
                    echo "Starting container for smoke test..."
                    // Run the container in the background, map a random host port
                    def container = docker.image(FULL_IMAGE).run('-d -P')

                    try {
                        // Give Nginx a couple of seconds to start
                        sleep 3

                        // Discover the host port that was mapped to container port 80
                        def hostPort = sh(
                            script: "docker port ${container.id} 80 | cut -d: -f2",
                            returnStdout: true
                        ).trim()

                        echo "Container is listening on host port ${hostPort}"

                        // Hit the page and fail the stage if we don't get HTTP 200
                        sh """
                            curl -f -s -o /dev/null -w "%{http_code}" http://localhost:${hostPort}/ | grep -q 200
                        """
                        echo "Smoke test passed – page returned HTTP 200"
                    } finally {
                        // Always stop and remove the test container
                        container.stop()
                        // docker.image(...).run() already removed it when stopped in most cases,
                        // but this is extra safety
                        sh "docker rm -f ${container.id} || true"
                    }
                }
            }
        }

        // ---------------------------------------------------
        // 4. Push the image to Docker Hub
        // ---------------------------------------------------
        stage('Push') {
            steps {
                script {
                    echo "Pushing ${FULL_IMAGE} to Docker Hub..."

                    // 'dockerhub-credentials' must exist in Jenkins
                    // (Manage Jenkins → Credentials → Username with password)
                    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub-credentials') {
                        def image = docker.image(FULL_IMAGE)
                        image.push()                         // push the build-number tag

                        if (params.PUSH_LATEST) {
                            image.push('latest')             // also push :latest
                            echo "Also pushed ${IMAGE_NAME}:latest"
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------
    // Post-build actions
    // -------------------------------------------------------
    post {
        always {
            // Clean up local images to keep the Jenkins agent disk clean
            echo "Cleaning up local Docker images..."
            sh """
                docker rmi ${FULL_IMAGE} || true
                docker rmi ${IMAGE_NAME}:latest || true
            """
        }
        success {
            echo "=============================================="
            echo " Pipeline succeeded!"
            echo " Image : ${FULL_IMAGE}"
            if (params.PUSH_LATEST) {
                echo " Also  : ${IMAGE_NAME}:latest"
            }
            echo "=============================================="
        }
        failure {
            echo "Pipeline failed. Check the stage logs above."
        }
        cleanup {
            // Extra safety – remove any leftover containers from failed tests
            sh 'docker ps -aq --filter "ancestor=${FULL_IMAGE}" | xargs -r docker rm -f || true'
        }
    }
}
