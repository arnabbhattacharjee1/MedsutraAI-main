# MedSutra AI Frontend - Deployment Package

Production-ready frontend for MedSutra AI Clinical Intelligence Platform.

## 🎯 Quick Links

- **[Quick Start](#-quick-start)** - Get running in 5 minutes
- **[AWS Deployment](#-deploy-to-aws-s3)** - Deploy to production
- **[GitHub Setup](#-github-setup)** - Version control
- **[Full Documentation](DEPLOYMENT.md)** - Complete guide

## 📦 What's Included

✅ Modern patient dashboard with 6 oncology cases  
✅ AI clinical assistant with chat interface  
✅ Multilingual support (6 Indian languages)  
✅ Patient report viewer with detailed medical data  
✅ Secure login system  
✅ Fully responsive design  
✅ AWS deployment scripts  
✅ CI/CD configuration  

## 🚀 Quick Start

### Test Locally (2 minutes)

```bash
# Using Python
python -m http.server 8000

# OR using Node.js
npx serve .

# Open browser
http://localhost:8000
```

**Demo Login:**
- User ID: `test user`
- Password: `test`
- Role: `Oncologist`

## ☁️ Deploy to AWS S3

### Prerequisites

- AWS CLI installed and configured
- S3 bucket created
- Appropriate IAM permissions

### Deployment Steps

#### Option 1: Using Deployment Script (Linux/Mac)

```bash
chmod +x deploy-s3.sh
./deploy-s3.sh your-bucket-name
```

#### Option 2: Using Deployment Script (Windows)

```powershell
.\deploy-s3.ps1 -BucketName your-bucket-name
```

#### Option 3: Manual Deployment

```bash
aws s3 sync . s3://your-bucket-name/ \
  --exclude "*.md" \
  --exclude "*.sh" \
  --exclude "*.ps1" \
  --exclude "buildspec.yml" \
  --delete
```

## 🔧 Configuration

### 1. Update API Endpoint

Edit `app.js` line 2:

```javascript
const CONFIG = {
    API_ENDPOINT: 'https://your-api-gateway-url.amazonaws.com/prod',
    // ...
};
```

### 2. Configure CORS on API Gateway

Add these headers to your API Gateway responses:

```json
{
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type"
}
```

## 🐙 GitHub Setup

### Initialize Repository

```bash
git init
git add .
git commit -m "Initial commit: MedSutra AI Frontend"
git remote add origin https://github.com/yourusername/medsutra-ai-frontend.git
git branch -M main
git push -u origin main
```

### Configure GitHub Secrets

Add these secrets in GitHub repository settings:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION` (e.g., us-east-1)
- `S3_BUCKET` (your bucket name)
- `CLOUDFRONT_DISTRIBUTION_ID` (optional)

The included GitHub Actions workflow will automatically deploy on push to main.

## 📱 Features

### Patient Dashboard
- 6 oncology patient tiles with real medical data
- Risk-based color coding (Critical, High, Medium, Low)
- Quick actions: View reports, AI analysis

### Patient Reports
- Detailed medical information
- Cancer staging and diagnosis
- Treatment plans
- Clinical notes

### AI Clinical Assistant
- Interactive chat interface
- Multilingual responses in 6 Indian languages
- Pre-configured medical analysis
- Quick action buttons

### Multilingual Support
- English
- Hindi (हिंदी)
- Tamil (தமிழ்)
- Telugu (తెలుగు)
- Bengali (বাংলা)
- Marathi (मराठी)

## 📊 Patient Data

1. **Raj Kumar** - Lung Cancer (Stage IIIB) - High Risk
2. **Priya Verma** - Breast Cancer (Stage IIA) - Medium Risk
3. **Amit Singh** - Pancreatic Cancer (Stage IV) - Critical Risk
4. **Sneha Patel** - Ovarian Cancer (Stage IIIC) - High Risk
5. **Vikram Sharma** - Prostate Cancer (Stage IIB) - Medium Risk
6. **Divya Iyer** - Melanoma (Stage IA) - Low Risk

## 🌐 Browser Support

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+
- Mobile browsers

## 📄 Files

- `index.html` - Main application HTML
- `styles.css` - Complete styling
- `app.js` - Application logic with multilingual support
- `deploy-s3.sh` - AWS deployment script (Linux/Mac)
- `deploy-s3.ps1` - AWS deployment script (Windows)
- `buildspec.yml` - AWS CodeBuild configuration
- `.github/workflows/deploy.yml` - GitHub Actions CI/CD

## 📚 Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Complete deployment guide
- **[PACKAGE-INFO.md](PACKAGE-INFO.md)** - Technical specifications
- **README.md** - This file

## 🔒 Security

- Always use HTTPS in production
- Configure CORS properly on API Gateway
- Implement AWS Cognito for authentication
- Enable S3 access logging
- Set up CloudWatch monitoring

## 🎯 Production Checklist

Before deploying to production:

- [ ] Update API endpoint in app.js
- [ ] Replace demo credentials with real authentication
- [ ] Configure CORS on API Gateway
- [ ] Set up CloudFront distribution
- [ ] Enable HTTPS
- [ ] Configure custom domain
- [ ] Set up monitoring and logging
- [ ] Perform security audit
- [ ] Test all features thoroughly

## 📞 Support

For issues or questions:
- Email: support@medsutra.ai
- Documentation: See DEPLOYMENT.md

## 📄 License

See main project LICENSE file.

---

**Made with ❤️ in India for Indian Healthcare**  
**Powered by Amazon Bedrock**
