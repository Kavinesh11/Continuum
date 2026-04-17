const fs = require('fs');
const path = require('path');

const LOG_PATH = path.join(__dirname, 'debug-a174ce.log');

function log(location, message, data, hypothesisId) {
  const entry = JSON.stringify({ sessionId: 'a174ce', location, message, data, hypothesisId, runId: 'post-fix', timestamp: Date.now() });
  fs.appendFileSync(LOG_PATH, entry + '\n');
}

// H1: Check for sqlx::query! macro usage without offline cache
const mainRs = fs.readFileSync(path.join(__dirname, 'services/claims_scoring/src/main.rs'), 'utf8');
const sqlxMacroMatches = mainRs.match(/sqlx::query!\s*\(/g);
const sqlxRuntimeMatches = mainRs.match(/sqlx::query_as\s*\(/g);

log('validate_builds.js:H1-postfix', 'sqlx::query! macro post-fix check', {
  sqlx_query_macro_count: sqlxMacroMatches ? sqlxMacroMatches.length : 0,
  sqlx_query_as_count: sqlxRuntimeMatches ? sqlxRuntimeMatches.length : 0,
  uses_coverage_cap_text_cast: mainRs.includes('coverage_cap::TEXT'),
  fix_applied: !sqlxMacroMatches || sqlxMacroMatches.length === 0,
}, 'H1');

// H2: Check crew_ai Dockerfile for build-essential
const crewDockerfile = fs.readFileSync(path.join(__dirname, 'services/crew_ai/Dockerfile'), 'utf8');
const hasBuildEssential = /build-essential/.test(crewDockerfile);
const hasGcc = /gcc/.test(crewDockerfile);

log('validate_builds.js:H2-postfix', 'crew_ai Dockerfile build tools post-fix check', {
  has_build_essential: hasBuildEssential,
  has_gcc: hasGcc,
  fix_applied: hasBuildEssential && hasGcc,
}, 'H2');

// H3: Check crew_ai env vars in docker-compose
const dockerCompose = fs.readFileSync(path.join(__dirname, 'docker-compose.yml'), 'utf8');
const crewSection = dockerCompose.split('crew_ai:')[1] || '';
const crewBlock = crewSection.split(/^\s{2}\w+:/m)[0] || '';
const hasPostgresUrl = /POSTGRES_URL/.test(crewBlock);
const hasMongoUri = /MONGODB_URI/.test(crewBlock);
const hasKgCacheUrl = /KG_CACHE_URL/.test(crewBlock);
const hasDependsOn = /depends_on/.test(crewBlock);

log('validate_builds.js:H3-postfix', 'crew_ai env vars post-fix check', {
  has_POSTGRES_URL: hasPostgresUrl,
  has_MONGODB_URI: hasMongoUri,
  has_KG_CACHE_URL: hasKgCacheUrl,
  has_depends_on: hasDependsOn,
  fix_applied: hasPostgresUrl && hasMongoUri,
}, 'H3');

console.log('Post-fix validation complete — check debug-a174ce.log');
