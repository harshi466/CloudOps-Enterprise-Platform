// Alternative to GitHub Actions: Jenkins declarative pipeline (Module 5)
pipeline {
  agent any
  environment {
    AWS_REGION = 'ap-south-1'
    PROJECT    = 'cloudops-dev'
    TAG        = "${env.GIT_COMMIT?.take(8) ?: 'local'}"
  }
  stages {
    stage('Test') {
      steps {
        sh '''
          for s in user-service expense-service; do
            (cd services/$s && python3 -m venv .venv && . .venv/bin/activate \
              && pip install -q -r requirements.txt -r requirements-dev.txt && pytest -q)
          done
        '''
      }
    }
    stage('Build images') {
      steps {
        sh '''
          for s in user-service expense-service; do docker build -t $PROJECT/$s:$TAG services/$s; done
          docker build -t $PROJECT/frontend:$TAG frontend
        '''
      }
    }
    stage('Push to ECR') {
      when { branch 'main' }
      steps {
        withAWS(region: env.AWS_REGION, credentials: 'aws-jenkins') {
          sh '''
            REG=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com
            aws ecr get-login-password | docker login --username AWS --password-stdin $REG
            for s in user-service expense-service frontend; do
              docker tag $PROJECT/$s:$TAG $REG/$PROJECT/$s:$TAG && docker push $REG/$PROJECT/$s:$TAG
            done
          '''
        }
      }
    }
    stage('Deploy to Kubernetes') {
      when { branch 'main' }
      steps { sh 'kubectl apply -k k8s' }
    }
  }
  post { failure { echo 'Pipeline failed - check the stage logs' } }
}
