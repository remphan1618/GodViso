# PRIMARY GitHub Actions Workflow (Builds standard VNC image)
# This workflow runs on GitHub-hosted runners (ubuntu-latest)

name: Build and Push VisoMaster PRIMARY Docker Image

on:
  push:
    branches:
      - main # Trigger on push to main
  workflow_dispatch: # Allow manual triggering

jobs:
  build-and-push:
    # Specify the type of runner the job will run on
    runs-on: ubuntu-latest # Using a standard GitHub-hosted Linux runner
    permissions:
      contents: read      # Allow reading repository content
      packages: write     # Allow pushing Docker image to Docker Hub/GHCR

    steps:
      - name: Checkout repository code
        uses: actions/checkout@v4
        # This step checks out your repository onto the runner machine

      - name: Set up QEMU for multi-platform builds (optional but good practice)
        uses: docker/setup-qemu-action@v3
        # Allows building images for different architectures if needed

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
        # Sets up Docker Buildx, an enhanced builder backend

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
        # Logs the runner into Docker Hub to allow pushing the image

      - name: Build and push PRIMARY Docker image
        uses: docker/build-push-action@v5
        with:
          context: . # Use the repository root as the build context
          file: ./Dockerfile # Specify the primary Dockerfile
          push: true # Push the image after building
          tags: | # Define tags for the image
            ${{ secrets.DOCKERHUB_USERNAME }}/visomaster:latest
            ${{ secrets.DOCKERHUB_USERNAME }}/visomaster:${{ github.sha }}
          # Use GitHub Actions cache for faster subsequent builds
          cache-from: type=gha
          cache-to: type=gha,mode=max
        # This step performs the 'docker build' and 'docker push' commands on the runner
