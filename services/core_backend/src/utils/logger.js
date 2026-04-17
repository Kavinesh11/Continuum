const LOG_LEVELS = { debug: 10, info: 20, warn: 30, error: 40 };

const currentLevel = LOG_LEVELS[process.env.LOG_LEVEL || 'info'] || LOG_LEVELS.info;

function formatEntry(level, message, meta = {}) {
  return JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    message,
    service: 'core_backend',
    ...meta,
  });
}

const logger = {
  debug(message, meta) {
    if (currentLevel <= LOG_LEVELS.debug) process.stdout.write(formatEntry('debug', message, meta) + '\n');
  },
  info(message, meta) {
    if (currentLevel <= LOG_LEVELS.info) process.stdout.write(formatEntry('info', message, meta) + '\n');
  },
  warn(message, meta) {
    if (currentLevel <= LOG_LEVELS.warn) process.stderr.write(formatEntry('warn', message, meta) + '\n');
  },
  error(message, meta) {
    if (currentLevel <= LOG_LEVELS.error) process.stderr.write(formatEntry('error', message, meta) + '\n');
  },
};

module.exports = logger;
