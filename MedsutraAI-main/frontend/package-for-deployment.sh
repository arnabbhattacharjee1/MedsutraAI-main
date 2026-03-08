#!/bin/bash

# MedSutra AI Frontend - Package for Deployment
# This script creates a clean deployment package

echo "📦 Packaging MedSutra AI Frontend for deployment..."

# Create dist directory if it doesn't exist
mkdir -p dist

# Copy main files
echo "Copying main files..."
cp new-index.html dist/index.html
cp styles.css dist/styles.css
cp app.js dist/app.js

echo "✅ Packaging complete!"
echo ""
echo "📁 Deployment package ready in: ./dist/"
echo ""
echo "Next steps:"
echo "1. cd dist"
echo "2. Review and update API endpoint in app.js"
echo "3. Deploy using: ./deploy-s3.sh your-bucket-name"
echo ""
echo "For GitHub:"
echo "1. cd dist"
echo "2. git init"
echo "3. git add ."
echo "4. git commit -m 'Initial commit'"
echo "5. git remote add origin <your-repo-url>"
echo "6. git push -u origin main"
