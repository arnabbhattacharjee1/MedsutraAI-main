# MedSutra AI Frontend - Deployment Checklist

Use this checklist to ensure successful deployment.

## ✅ Pre-Deployment

### Local Testing
- [ ] Files copied to `dist/` folder
- [ ] Tested locally with `python -m http.server 8000`
- [ ] Login works with demo credentials
- [ ] Patient dashboard displays correctly
- [ ] Patient reports open in modal
- [ ] AI analysis works in all 6 languages
- [ ] Language switching functions properly
- [ ] All buttons and links work
- [ ] No console errors
- [ ] Responsive design tested on mobile

### Configuration
- [ ] API endpoint updated in `app.js`
- [ ] Demo credentials reviewed (or replaced)
- [ ] CORS configured on API Gateway
- [ ] Environment-specific settings updated

## ☁️ AWS Setup

### S3 Bucket
- [ ] S3 bucket created
- [ ] Bucket name documented
- [ ] Static website hosting enabled
- [ ] Bucket policy configured for public read
- [ ] Index document set to `index.html`
- [ ] Error document set to `index.html`

### CloudFront (Recommended)
- [ ] CloudFront distribution created
- [ ] Origin set to S3 bucket
- [ ] Default root object set to `index.html`
- [ ] Custom error responses configured (403→index.html, 404→index.html)
- [ ] HTTPS enabled
- [ ] ACM certificate attached (if using custom domain)
- [ ] Distribution ID documented

### IAM Permissions
- [ ] IAM user/role has S3 permissions
- [ ] IAM user/role has CloudFront permissions (if using)
- [ ] AWS CLI configured with credentials
- [ ] Credentials tested with `aws sts get-caller-identity`

## 🚀 Deployment

### Initial Deployment
- [ ] Deployment script executed successfully
- [ ] Files uploaded to S3
- [ ] Content types set correctly
- [ ] CloudFront cache invalidated (if using)
- [ ] S3 website URL tested
- [ ] CloudFront URL tested (if using)

### Verification
- [ ] Application loads without errors
- [ ] All assets load correctly (CSS, JS)
- [ ] Login functionality works
- [ ] Patient dashboard displays
- [ ] Patient reports open
- [ ] AI analysis works
- [ ] Language switching works
- [ ] Mobile responsive design works

## 🐙 GitHub Setup

### Repository
- [ ] GitHub repository created
- [ ] Local git initialized
- [ ] Files committed
- [ ] Remote added
- [ ] Code pushed to GitHub
- [ ] Repository is public/private as intended

### GitHub Secrets
- [ ] `AWS_ACCESS_KEY_ID` added
- [ ] `AWS_SECRET_ACCESS_KEY` added
- [ ] `AWS_REGION` added
- [ ] `S3_BUCKET` added
- [ ] `CLOUDFRONT_DISTRIBUTION_ID` added (if using)

### GitHub Actions
- [ ] Workflow file in `.github/workflows/deploy.yml`
- [ ] Workflow runs successfully
- [ ] Automatic deployment works on push

## 🔒 Security

### Production Security
- [ ] HTTPS enabled (via CloudFront)
- [ ] CORS properly configured
- [ ] Demo credentials replaced with real auth (AWS Cognito)
- [ ] S3 bucket not publicly writable
- [ ] CloudFront signed URLs configured (if needed)
- [ ] AWS WAF rules configured (if needed)
- [ ] Rate limiting enabled on API Gateway

### Monitoring & Logging
- [ ] S3 access logging enabled
- [ ] CloudWatch alarms configured
- [ ] CloudFront logging enabled
- [ ] API Gateway logging enabled
- [ ] Error tracking set up

## 📊 Post-Deployment

### Testing
- [ ] Full end-to-end testing completed
- [ ] All features tested in production
- [ ] Performance testing completed
- [ ] Load testing completed (if needed)
- [ ] Security audit completed
- [ ] Accessibility testing completed

### Documentation
- [ ] Deployment documented
- [ ] API endpoint documented
- [ ] Custom domain documented (if using)
- [ ] Team members trained
- [ ] User guide created (if needed)

### Monitoring
- [ ] CloudWatch dashboard created
- [ ] Billing alarms set up
- [ ] Performance metrics tracked
- [ ] Error rates monitored
- [ ] User analytics configured (if needed)

## 🎯 Production Readiness

### Critical Items
- [ ] API endpoint is production URL (not dev/test)
- [ ] Demo credentials replaced with real authentication
- [ ] HTTPS enforced
- [ ] Error handling implemented
- [ ] Backup and recovery plan in place

### Nice to Have
- [ ] Custom domain configured
- [ ] CDN optimization completed
- [ ] Image optimization completed
- [ ] Analytics tracking added
- [ ] User feedback mechanism added

## 📞 Support & Maintenance

### Documentation
- [ ] README.md updated with production URLs
- [ ] DEPLOYMENT.md reviewed
- [ ] Team has access to documentation
- [ ] Runbook created for common issues

### Contacts
- [ ] Support email configured
- [ ] On-call rotation established (if needed)
- [ ] Escalation path documented
- [ ] Vendor contacts documented

## 🔄 Ongoing Maintenance

### Regular Tasks
- [ ] Monitor CloudWatch metrics weekly
- [ ] Review S3 access logs monthly
- [ ] Update dependencies (none currently)
- [ ] Review and rotate AWS credentials quarterly
- [ ] Perform security audits quarterly
- [ ] Review and optimize costs monthly

### Updates
- [ ] Process for deploying updates documented
- [ ] Rollback procedure documented
- [ ] Change management process established
- [ ] Testing procedure for updates established

---

## 📝 Notes

Use this space to document any deployment-specific notes:

**S3 Bucket:** ___________________________

**CloudFront Distribution ID:** ___________________________

**Custom Domain:** ___________________________

**API Gateway URL:** ___________________________

**Deployment Date:** ___________________________

**Deployed By:** ___________________________

**Production URL:** ___________________________

---

**Status:** ⬜ Not Started | 🟡 In Progress | ✅ Complete

**Last Updated:** March 8, 2026
