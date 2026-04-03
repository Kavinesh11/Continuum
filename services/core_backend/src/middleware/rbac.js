// Feature: continuum-ml-pipelines
// Role-Based Access Control middleware — Requirements 6.4

/**
 * Role guard middleware factory.
 * Returns middleware that checks req.user.role is in the allowed roles list.
 * Returns HTTP 403 with {"error": "insufficient_role"} on violation.
 *
 * @param {...string} roles - Allowed roles (e.g. 'worker', 'admin', 'insurer')
 * @returns {Function} Express middleware
 */
function requireRole(...roles) {
  return function (req, res, next) {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'insufficient_role' });
    }
    next();
  };
}

module.exports = { requireRole };
