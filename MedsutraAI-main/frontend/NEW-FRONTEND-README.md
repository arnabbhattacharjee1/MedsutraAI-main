# MedSutra AI - New Frontend

Modern, responsive frontend for the MedSutra AI clinical intelligence platform.

## Features

- **Modern UI/UX**: Clean, professional design with smooth animations
- **AI Chat Interface**: Interactive chat with the AI clinical assistant
- **Quick Actions**: Pre-defined prompts for common tasks
- **Multilingual Support**: Toggle between 10+ Indian languages
- **Responsive Design**: Works on desktop, tablet, and mobile
- **Real-time Updates**: Live status indicators and typing animations
- **Persistent Storage**: Conversation history saved locally

## Files

- `new-index.html` - Main HTML structure
- `styles.css` - Complete styling with CSS variables
- `app.js` - JavaScript functionality and API integration

## Setup

1. **Configure API Endpoint**
   
   Edit `app.js` and update the API endpoint:
   ```javascript
   const CONFIG = {
       API_ENDPOINT: 'https://your-api-gateway-url.amazonaws.com/prod',
       // ...
   };
   ```

2. **Deploy to S3 + CloudFront**
   
   ```bash
   # Upload files to S3 bucket
   aws s3 sync . s3://your-bucket-name/ --exclude "*.md"
   
   # Invalidate CloudFront cache
   aws cloudfront create-invalidation --distribution-id YOUR_DIST_ID --paths "/*"
   ```

3. **Or serve locally for testing**
   
   ```bash
   # Using Python
   python -m http.server 8000
   
   # Using Node.js
   npx serve .
   ```

## API Integration

The frontend expects the following API response format:

```json
{
  "response": "AI generated response text",
  "confidence": 0.95,
  "sources": ["source1", "source2"]
}
```

## Customization

### Colors

Edit CSS variables in `styles.css`:

```css
:root {
    --navy: #0B131D;
    --cyan: #AFE6DE;
    --green: #C7E1B8;
    /* ... */
}
```

### Languages

Add more languages in `app.js`:

```javascript
const CONFIG = {
    LANGUAGES: ['English', 'Hindi', 'Tamil', 'Telugu', 'Bengali', 'Marathi', 'Gujarati']
};
```

## Browser Support

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

## Performance

- Optimized CSS with minimal reflows
- Lazy loading for images
- LocalStorage for conversation persistence
- Debounced API calls

## Security

- No sensitive data in localStorage
- HTTPS required for production
- Content Security Policy headers recommended
- Input sanitization on backend

## Next Steps

1. Connect to actual Lambda functions
2. Add authentication (Cognito)
3. Implement voice input/output
4. Add file upload for medical reports
5. Create admin dashboard
6. Add analytics tracking

## License

See main project LICENSE file.
