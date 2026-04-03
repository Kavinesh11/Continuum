# Feature: continuum-ml-pipelines
import sys
import os

# Add the parent directory (services/fastapi_gateway) to sys.path so that
# `main` and `models` can be imported without a package install.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
