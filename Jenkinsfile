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
            echo "Starting ASP.NET container..."

            // Start container and capture its actual ID
            def containerId = powershell(
                script: """
                    docker run --detach --publish 8081:8080 ${FULL_IMAGE}
                """,
                returnStdout: true
            ).trim()

            echo "Container ID: ${containerId}"

            try {
                echo "Waiting for ASP.NET application..."

                def response = powershell(
                    script: '''
                        $maxAttempts = 10
                        $success = $false

                        for ($i = 1; $i -le $maxAttempts; $i++) {
                            try {
                                $response = Invoke-WebRequest `
                                    -Uri "http://localhost:8081/" `
                                    -UseBasicParsing `
                                    -TimeoutSec 5

                                if ($response.StatusCode -eq 200) {
                                    $success = $true
                                    break
                                }
                            }
                            catch {
                                Write-Output "Attempt $i failed: $($_.Exception.Message)"
                                Start-Sleep -Seconds 2
                            }
                        }

                        if (-not $success) {
                            throw "ASP.NET smoke test failed."
                        }

                        Write-Output "HTTP Status: $($response.StatusCode)"
                    ''',
                    returnStdout: true
                ).trim()

                echo response
                echo "Smoke test passed!"

            } catch (Exception e) {

                echo "Smoke test failed. Collecting container logs..."

                powershell """
                    docker logs ${containerId}
                """

                throw e

            } finally {

                echo "Removing test container..."

                powershell """
                    docker rm -f ${containerId}
                """
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
                    docker.withRegistry('https://index.docker.io/v1/', '9766f83d-7c0b-4bde-95f4-103ec74e1d22') {
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
