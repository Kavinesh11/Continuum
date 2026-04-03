# Feature: continuum-ml-pipelines
import sys
import os

# Add the parent directory (services/risk_profiler) to sys.path so that
# `feature_builder` can be imported without a package install.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
