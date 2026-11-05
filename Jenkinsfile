pipeline {
    agent any

    // -------------------------------------------------------
    // Parameters – you can change these when you trigger the job
    // -------------------------------------------------------
    parameters {
        string(
            name: 'DOCKERHUB_USERNAME',
            defaultValue: 'jonahteal',
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
                    def customImage = docker.build(FULL_IMAGE)
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
                    // Run the container in the background, publish a random host port
                    def container = docker.image(FULL_IMAGE).run('-d -P')

                    try {
                        // Give Nginx a couple of seconds to start
                        sleep 3

                        // On Windows, docker port returns something like:
                        // 0.0.0.0:32768
                        // We extract the port number with PowerShell
                        def hostPort = powershell(
                            returnStdout: true,
                            script: """
                                \$portLine = docker port ${container.id} 80
                                if (\$portLine -match ':(\\d+)\$') {
                                    \$matches[1]
                                } else {
                                    throw "Could not parse port from: \$portLine"
                                }
                            """
                        ).trim()

                        echo "Container is listening on host port ${hostPort}"

                        // Hit the page and fail the stage if we don't get HTTP 200
                        // Using PowerShell's Invoke-WebRequest
                        powershell """
                            \$response = Invoke-WebRequest -Uri "http://localhost:${hostPort}/" -UseBasicParsing -ErrorAction Stop
                            if (\$response.StatusCode -ne 200) {
                                throw "Expected HTTP 200 but got \$(\$response.StatusCode)"
                            }
                            Write-Host "Smoke test passed – page returned HTTP 200"
                        """
                    } finally {
                        // Always stop and remove the test container
                        container.stop()
                        bat "docker rm -f ${container.id} || exit 0"
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

                    // Credential ID must match what you created in Jenkins
                    docker.withRegistry('https://index.docker.io/v1/', 'Docker-Creds') {
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
            bat """
                docker rmi ${FULL_IMAGE} 2>nul || exit 0
                docker rmi ${IMAGE_NAME}:latest 2>nul || exit 0
            """
        }
        success {
            script {
                echo "=============================================="
                echo " Pipeline succeeded!"
                echo " Image : ${FULL_IMAGE}"
                if (params.PUSH_LATEST) {
                    echo " Also  : ${IMAGE_NAME}:latest"
                }
                echo "=============================================="
            }
        }
        failure {
            echo "Pipeline failed. Check the stage logs above."
        }
        cleanup {
            // Extra safety – remove any leftover containers from failed tests
            bat """
                for /f "tokens=*" %%i in ('docker ps -aq --filter "ancestor=${FULL_IMAGE}" 2^>nul') do docker rm -f %%i 2>nul
                exit 0
            """
        }
    }
}
