
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        // KUBECONFIG_CREDENTIALS_ID = 'EKS_Kubeconfig'
        AWS_ENDPOINT_URL = 'http://floci:4566'
        AWS_DEFAULT_REGION = 'us-east-1'
        EKS_CLUSTER_NAME = 'floci-eks-cluster'
        AWS_ACCESS_KEY_ID = credentials('aws-credentials')
        AWS_SECRET_ACCESS_KEY = credentials('aws-credentials')
        ANSIBLE_DIR="ansible"
        
        // K8S_MANIFEST_DIR = 'k8s'
        TERRAFORM_DIR = 'terraform'
    }

    stages {

        // -----------------------------------------------
        // 1. CHECKOUT SOURCE CODE
        // -----------------------------------------------
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // -----------------------------------------------
        // 2. CHECK JENKINS AGENT DEPEND
        // ENCIES
        // -----------------------------------------------
        stage('Check Dependencies') {
            steps {
                sh '''
                    echo "Checking Jenkins agent dependencies..."

                    terraform --version
                    aws --version
                    ansible --version
                    python3 --version
                    kubectl version --client
                    helm version

                    echo "Checking repository structure..."

                    test -d "$ANSIBLE_DIR"
                    test -f "$ANSIBLE_DIR/playbook-floci-eks.yaml"
                    test -d "$TERRAFORM_DIR"
                    test -f "$TERRAFORM_DIR/providers.tf"
                    test -f "$TERRAFORM_DIR/resources.tf"

                    echo "Dependencies and files verified."
                '''
            }
        }

        // -----------------------------------------------
        // 3. TERRAFORM INFRASTRUCTURE PROVISIONING
        // -----------------------------------------------
        stage('Terraform Infrastructure Provisioning') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    sh '''
                        set -e

                        echo "Initializing Terraform..."

                        terraform init

                        echo "Validating Terraform configuration..."

                        terraform validate

                        echo "Generating Terraform execution plan..."

                        terraform plan \
                            -out=tfplan

                        echo "Applying Terraform infrastructure..."

                        terraform apply -auto-approve tfplan

                        echo "Terraform infrastructure provisioned."
                    '''
                }
            }
        }

        // 4. GENERATE KUBECONFIG
        stage('Configure Kubernetes Access') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
            )
        ]) {
                sh '''
                    set -e

                    echo "Waiting for LocalStack EKS cluster..."

                    mkdir -p "$(dirname "$KUBECONFIG")"

                    aws eks wait cluster-active \
                        --name "$EKS_CLUSTER_NAME"

                    echo "Generating kubeconfig..."

                    aws eks update-kubeconfig \
                        --name "$EKS_CLUSTER_NAME"

                    echo "Checking Kubernetes connectivity..."

                    kubectl config current-context
                    kubectl get nodes

                    echo "Kubernetes access configured."
                '''
            }
        }
        }

        // -----------------------------------------------
        // 5. RUN ANSIBLE PLAYBOOK
        // -----------------------------------------------
        stage('Install EKS Prerequisites') {
            steps{
                    sh '''
                        set -e

                        echo "Starting Ansible infrastructure installation..."

                        ansible-playbook \
                            -i localhost, \
                            -c local \
                            "$ANSIBLE_PLAYBOOK" \
                            -e "kubeconfig=$KUBECONFIG"

                        echo "Ansible execution completed."
                    '''
                }
        }

        // -----------------------------------------------
        // 6. VERIFY INFRASTRUCTURE
        // -----------------------------------------------
        stage('Verify Infrastructure') {
            steps {
                    sh '''
                        set -e
                        
                        echo "Checking Kubernetes nodes..."
                        kubectl get nodes

                        echo "Checking namespaces..."
                        kubectl get namespaces

                        echo "Checking Helm releases..."
                        helm list -A

                        echo "Checking ArgoCD pods..."
                        kubectl get pods -n argocd

                        echo "Checking Monitoring pods..."
                        kubectl get pods -n monitoring
                    '''
                }
            }
        }

        // // -----------------------------------------------
        // // 5. DEPLOY KUBERNETES YAML FILES
        // // -----------------------------------------------
        // stage('Deploy Kubernetes Manifests') {
        //     steps {
        //         withCredentials([
        //             file(
        //                 credentialsId: "${KUBECONFIG_CREDENTIALS_ID}",
        //                 variable: 'KUBECONFIG'
        //             )
        //         ]) {
        //             sh '''
        //                 echo "Deploying Kubernetes YAML manifests..."

        //                 kubectl apply -f "$K8S_MANIFEST_DIR/"

        //                 echo "Kubernetes manifests applied."
        //             '''
        //         }
        //     }
        // }

    //     // -----------------------------------------------
    //     // 6. VERIFY APPLICATION DEPLOYMENT
    //     // -----------------------------------------------
    //     stage('Verify Application Deployment') {
    //         steps {
    //             withCredentials([
    //                 file(
    //                     credentialsId: "${KUBECONFIG_CREDENTIALS_ID}",
    //                     variable: 'KUBECONFIG'
    //                 )
    //             ]) {
    //                 sh '''
    //                     echo "Checking application deployments..."

    //                     kubectl get deployments -A

    //                     echo "Checking pods..."
    //                     kubectl get pods -A

    //                     echo "Checking services..."
    //                     kubectl get services -A

    //                     echo "Checking rollout status..."

    //                     kubectl get deployments -n default -o name |
    //                     while read deployment; do
    //                         kubectl rollout status "$deployment" \
    //                             -n default --timeout=300s
    //                     done
    //                 '''
    //             }
    //         }
    //     }
    // }

    post {
        success {
            echo '''
            ==========================================
            PIPELINE SUCCESS
            ==========================================
            Terraform infrastructure provisioned.
            Kubernetes access configured.
            Ansible prerequisites installed.
            Prometheus and Grafana installed.
            ArgoCD installed.
            ==========================================
            '''
            // Kubernetes manifests deployed.
        }

        failure {
            echo 'Pipeline failed. Check Jenkins console output.'
        }

        always {
            echo 'Jenkins pipeline execution finished.'
        }
    }
}
