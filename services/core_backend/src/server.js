// Feature: continuum-ml-pipelines
// Server entry point

const app = require('./app');

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Core Backend listening on port ${PORT}`);
});
