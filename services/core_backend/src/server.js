// Feature: continuum-ml-pipelines
// Server entry point

const app = require('./app');

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

app.listen(PORT, HOST, () => {
  console.log(`Core Backend listening on http://${HOST}:${PORT}`);
});
