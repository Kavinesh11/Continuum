const { cleanEnv, str, port, bool, url } = require('envalid');

const INSECURE_DEFAULTS = ['change_me_to_a_long_random_secret', 'secret', 'password'];

function validateEnv() {
  const env = cleanEnv(process.env, {
    JWT_SECRET: str({ desc: 'JWT signing secret' }),
    PORT: port({ default: 3000 }),

    DB_HOST: str({ default: 'localhost' }),
    DB_PORT: port({ default: 5432 }),
    DB_NAME: str({ default: 'continuum' }),
    DB_USER: str({ default: 'postgres' }),
    DB_PASSWORD: str({ default: '' }),
    DB_SSL: bool({ default: false }),

    KAFKA_BROKERS: str({ 
      default: process.env.KAFKA_BOOTSTRAP_SERVERS || 'localhost:9092' 
    }),

    NODE_ENV: str({ choices: ['development', 'test', 'production'], default: 'development' }),
  });

  if (env.isProd && INSECURE_DEFAULTS.includes(env.JWT_SECRET)) {
    throw new Error('JWT_SECRET must not use an insecure default value in production');
  }

  if (env.isProd && !env.DB_SSL) {
    console.warn('[config] WARNING: DB_SSL is false in production — database traffic is unencrypted');
  }

  return env;
}

module.exports = { validateEnv };
