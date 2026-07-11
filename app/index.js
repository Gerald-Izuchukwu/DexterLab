const express = require('express');

const app = express();
const PORT = process.env.PORT || 8080;

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from the Dexter CyberLab wallet backend placeholder service',
    service: 'wallet-app',
    timestamp: new Date().toISOString(),
  });
});

// Health check used by the ALB target group and by ECS container health checks
app.get('/healthz', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`wallet-app listening on port ${PORT}`);
  });
}

module.exports = app;
