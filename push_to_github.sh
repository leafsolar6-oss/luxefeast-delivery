#!/bin/bash
# Push script for LuxFeast to GitHub
# Requires: git, a GitHub account, and a new remote repo URL

echo "=========================================="
echo "LuxFeast GitHub Push Script"
echo "=========================================="

if [ -z "$1" ]; then
  echo "Usage: ./push_to_github.sh <github_repo_url>"
  echo "Example: ./push_to_github.sh https://github.com/YOUR_USER/luxefeast.git"
  exit 1
fi

git remote add origin "$1" 2>/dev/null || git remote set-url origin "$1"

echo "Staging all files..."
git add .

echo "Committing..."
git commit -m "feat: LuxFeast v1.0 — Customer, Shop, Rider apps + Real-time Backend" || echo "Nothing new to commit."

echo "Pushing to origin/main..."
git push -u origin main

echo "=========================================="
echo "Done! Visit your repo: $1"
echo "=========================================="
